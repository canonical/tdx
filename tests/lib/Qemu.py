#
# Copyright 2024 Canonical Ltd.
# Authors:
# - Hector Cao <hector.cao@canonical.com>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranties of MERCHANTABILITY,
# SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#

import enum
import os
import logging
import paramiko
import pathlib
import shutil
import socket
import subprocess
import tempfile
import time
import sys
import stat
import json
import util

script_path=os.path.dirname(os.path.realpath(__file__))

class QemuEfiMachine(enum.Enum):
    OVMF_Q35 = 1
    OVMF_Q35_TDX = 2

class QemuEfiVariant(enum.Enum):
    MS = 1
    SECBOOT = 2
    SNAKEOIL = 3

class QemuEfiFlashSize(enum.Enum):
    DEFAULT = 1
    SIZE_4MB = 2

class QemuAccel:
    def __init__(self):
        self.accel = 'kvm'
    def args(self):
        return ['-accel', self.accel]

class QemuCpu:
    def __init__(self):
        self.cpu_type = 'host'
        self.cpu_flags = ''
        self.nb_cores=4
        self.nb_sockets=1
    def args(self):
        smp = ['-smp', f'{self.nb_cores},sockets={self.nb_sockets}']
        if self.cpu_flags != '':
            cpu = ['-cpu', self.cpu_type + self.cpu_flags]
        else:
            cpu = ['-cpu', self.cpu_type]
        return cpu + smp

class QemuGraphic():
    def __init__(self):
        self.nographic = True
    def args(self):
        if self.nographic == True:
            return ['-nographic']
        return []

class QemuSerial():
    def __init__(self, serial_file : str = None):
        self.serial_file = serial_file
    def args(self):
        if self.serial_file:
            return [
                '-chardev', f'file,id=c1,path={self.serial_file},signal=off',
                '-device', 'isa-serial,chardev=c1'
            ]
        return ['-serial', 'stdio']

class QemuUserConfig:
    def __init__(self):
        self.nodefaults = True
        self.user_config = False
    def args(self):
        _args = []
        if self.nodefaults == True:
            _args.extend(['-nodefaults'])
        if self.user_config == False:
            _args.extend(['-no-user-config'])
        return _args

class QemuMemory:
    def __init__(self, memory = '2G'):
        self.memory = memory
    def args(self):
        return ['-m', self.memory]

class QemuOvmf():
    def __init__(self, machine):
        # cannot use pflash with kvm accel, need kvm support
        # so use bios by default
        self.bios = True
        self.bios_path = '/usr/share/edk2/ovmf/OVMF.inteltdx.fd'
        self.ovmf_code_path = None
        self.ovmf_vars_template_path = None
        self.flash_size = QemuEfiFlashSize.SIZE_4MB
        self.variant = None
        self.machine = machine
    def _get_default_flash_paths(self, machine, variant, flash_size):
        assert(machine in QemuEfiMachine)
        assert(variant is None or variant in QemuEfiVariant)
        assert(flash_size in QemuEfiFlashSize)

        # Remaining possibilities are OVMF variants
        assert(
            flash_size in [
                QemuEfiFlashSize.DEFAULT, QemuEfiFlashSize.SIZE_4MB
            ]
        )
        size_ext = '_4M'
        OVMF_ARCH = "OVMF"
        return (
            f'/usr/share/OVMF/{OVMF_ARCH}_CODE{size_ext}.ms.fd',
            f'/usr/share/OVMF/{OVMF_ARCH}_VARS{size_ext}.fd'
        )
    def args(self):
        _args = []
        if self.bios:
            _args = ['-bios', self.bios_path]
        else:
            if not self.ovmf_code_path:
                (self.ovmf_code_path, self.ovmf_vars_template_path) = self._get_default_flash_paths(
                    self.machine, self.variant, self.flash_size)
            pflash = self.PflashParams(self.ovmf_code_path, self.ovmf_vars_template_path)
            _args = pflash.params
        return _args

    class PflashParams:
        '''
        Used to generate the appropriate -pflash arguments for QEMU. Mostly
        used as a fancy way to generate a per-instance vars file and have it
        be automatically cleaned up when the object is destroyed.
        '''
        def __init__(self, ovmf_code_path, ovmf_vars_template_path):
            self.params = [
                '-drive',
                'file=%s,if=pflash,format=raw,unit=0,readonly=on' %
                (ovmf_code_path),
            ]
            if ovmf_vars_template_path is None:
                self.varfile_path = None
                return
            with tempfile.NamedTemporaryFile(delete=False) as varfile:
                self.varfile_path = varfile.name
                with open(ovmf_vars_template_path, 'rb') as template:
                    shutil.copyfileobj(template, varfile)
                    self.params = self.params + [
                        '-drive',
                        'file=%s,if=pflash,format=raw,unit=1,readonly=off' %
                        (varfile.name)
                    ]

        def __del__(self):
            if self.varfile_path is None:
                return
            os.unlink(self.varfile_path)

class QemuMachineType:
    Qemu_Machine_Params = {
        QemuEfiMachine.OVMF_Q35:['-machine', 'q35,kernel_irqchip=split'],
        QemuEfiMachine.OVMF_Q35_TDX:[
            '-machine', 'q35,hpet=off,kernel_irqchip=split,confidential-guest-support=tdx']
    }
    def __init__(self, machine = QemuEfiMachine.OVMF_Q35_TDX):
        self.machine = machine
        self.qgs_addr = None
    def enable_qgs_addr(self, addr : dict = {'type': 'vsock', 'cid':'3','port':'4050'}):
        """
        Enable the QGS (Quote Generation Service) address
        The address is a dictionary that corresponds to the object
        (https://qemu-project.gitlab.io/qemu/interop/qemu-qmp-ref.html#qapidoc-77)
        By default, the address is a vsock address with cid=2 (host cid) and port=4050
        """
        self.qgs_addr = addr
    def args(self):
        qemu_args = self.Qemu_Machine_Params[self.machine]
        if self.machine == QemuEfiMachine.OVMF_Q35_TDX:
            tdx_object = {'qom-type':'tdx-guest', 'id':'tdx'}
            if self.qgs_addr:
                tdx_object.update({"quote-generation-socket": self.qgs_addr})
            qemu_args = ['-object', str(tdx_object)] + qemu_args
        return qemu_args

class QemuBootType:
    def __init__(self,
                 image_path=None,
                 kernel=None,
                 initrd=None,
                 append=None):
        self.image_path = image_path
        self.kernel = kernel
        self.initrd = initrd
        self.append = append

    def args(self):
        _args = []
        if self.kernel:
            _args.extend(['-kernel', self.kernel])
            if self.append:
                _args.extend(['-append', f'{self.append}'])
            else:
                _args.extend(['-append', 'root=/dev/vda1 console=ttyS0'])
        if self.initrd:
            _args.extend(['-initrd', self.initrd])
        _args.extend([
            '-drive', f'file={self.image_path},if=none,id=virtio-disk0',
            '-device', 'virtio-blk-pci,drive=virtio-disk0'])
        return _args

class QemuCommand:

    def __init__(
            self,
            workdir,
            machine,
            memory='2G',
            variant=None,
    ):
        self.workdir = workdir
        self.plugins = {'cpu': QemuCpu(),
                        'accel': QemuAccel(),
                        'graphic': QemuGraphic(),
                        'config': QemuUserConfig(),
                        'memory': QemuMemory(memory),
                        'ovmf' : QemuOvmf(machine),
                        'serial' : QemuSerial(f'{self.workdir}/serial.log'),
                        'machine' : QemuMachineType(machine)}
        self.plugins['machine'].enable_qgs_addr()
        self.command = ['-pidfile', f'{self.workdir}/qemu.pid', '-vga', 'none']

    def get_command(self):
        _args = ['/usr/libexec/qemu-kvm']
        for p in self.plugins.values():
            _args.extend(p.args())
        return _args + self.command

    def add_qemu_run_log(self):
        # serial to file
        self.command = self.command + [
            '-D', f'{self.workdir}/qemu-log.txt'
        ]

    def add_port_forward(self, fwd_port):
        self.command = self.command + [
            '-device', 'virtio-net-pci,netdev=nic0_td',
            '-netdev', f'user,id=nic0_td,hostfwd=tcp::{fwd_port}-:22'
        ]

    def add_image(self, image_path):
        self.plugins['boot'] = QemuBootType(image_path=image_path)

    def add_qmp(self):
        try:
            if self.qmp_file is not None:
                return self.qmp_file
        except AttributeError:
            pass
        self.qmp_file = f'{self.workdir}/qmp.sock'
        self.command = self.command + [
            '-qmp', f'unix:{self.qmp_file},server=on,wait=off',
        ]

    def add_vsock(self, guest_cid):
        # Check if guest_cid already exists in the command list
        cid_exists = False
        for i in range(len(self.command)):
            if 'vhost-vsock-pci,guest-cid=' in self.command[i]:
                self.command[i] = 'vhost-vsock-pci,guest-cid=%d' % (guest_cid)
                cid_exists = True
                break

        # If guest_cid does not exist, add it to the command list
        if not cid_exists:
            self.command = self.command + [
                '-device', 'vhost-vsock-pci,guest-cid=%d' % (guest_cid),
            ]


    def add_monitor(self):
        try:
            if self.monitor_file is not None:
                return self.monitor_file
        except AttributeError:
            pass
        self.monitor_file = f'{self.workdir}/monitor.sock'
        self.command = self.command + [
            '-monitor', 'unix:%s,server,nowait' % (self.monitor_file)
        ]
        return self.monitor_file

class QemuMonitor():
    DELIMITER_STRING = '(qemu)'
    READ_TIMEOUT = 2
    CONNECT_RETRIES = 60

    def __new__(cls, qemu):
        # only 1 monitor per qemu machine
        if qemu.monitor is None:
            qemu.monitor = super().__new__(cls)
        return qemu.monitor

    def __init__(self, qemu):
        self.socket = None
        assert qemu.qcmd.monitor_file != None, "Monitor socket file is undefined"
        self.socket = socket.socket(socket.AF_UNIX,
                                    socket.SOCK_STREAM)
        for _ in range(self.CONNECT_RETRIES):
            try:
                print(f'Try to connect to qemu : {qemu.qcmd.monitor_file}')
                self.socket.connect(qemu.qcmd.monitor_file)
                # connection ok -> exit
                break
            except Exception as e:
                # give some time to make sure socket file is available
                time.sleep(1)
        self.socket.settimeout(self.READ_TIMEOUT)
        # wait for prompt
        print(f'Connected : {qemu.qcmd.monitor_file}, wait for prompt.')
        self.wait_prompt()

    def recv_data(self):
        msg = ''
        try:
            while True:
                recv_data = self.socket.recv(1024)
                # empty data is returned -> connection closed by remote peer
                if len(recv_data) == 0:
                    break
                msg += recv_data.decode('utf-8')
        except:
            pass
        return msg

    def wait_prompt(self):
        msg = self.recv_data()
        assert self.DELIMITER_STRING in msg, f'Fail on wait for monitor prompt : {msg}'

    def recv(self):
        """
        Return an array of messages from qemu process
        separated by the prompt string (qemu)
        Example:
        (qemu) running
        (qemu) rebooting
        will result in the returned value : [' running', ' rebooting']
        """
        msg = self.recv_data()
        return msg.split(self.DELIMITER_STRING)

    def send_command(self, cmd):
        self.socket.send(cmd.encode('utf-8'))
        self.socket.send(b"\r")
        print('[QEMU>>] %s' % (cmd))
        msgs = self.recv()
        for m in msgs:
            print('[QEMU<<] %s' % (m))
        return msgs

    def wait_for_state(self, s, retries=5):
        for _ in range(retries):
            msgs = self.send_command("info status")
            if len(msgs) <= 0 or len(msgs[0]) <= 0:
                time.sleep(1)
                continue
            for m in msgs:
                if s in m:
                    return True
        raise RuntimeError('Check state failed : %s' % (s))

    def wakeup(self):
        self.send_command("system_wakeup")

    def powerdown(self):
        self.send_command("system_powerdown")

    def __del__(self):
        if self.socket is not None:
            self.socket.close()

class QemuSSH():
    CONNECT_SLEEP = 1
    CONNECT_TIMEOUT = 60

    def __init__(self,
                 qemu_machine,
                 timeout=CONNECT_TIMEOUT):
        assert qemu_machine.fwd_port != None

        self.username = 'root'
        self.password = '123456'
        self.private_key = paramiko.RSAKey.from_private_key_file('/home/sdp/bprashan/centos_keys/id_rsa')
        self.port = qemu_machine.fwd_port

        # prevent paramiko to do spurious logs on stdout
        paramiko.util.log_to_file(filename=f'{qemu_machine.workdir_name}/paramiko-log.txt', level=logging.DEBUG)

        self._wait_and_connect(qemu_machine.fwd_port, timeout=timeout)

    def _wait_and_connect(self, port, timeout=CONNECT_TIMEOUT):
        self.ssh_conn = paramiko.SSHClient()
        self.ssh_conn.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh_conn.load_system_host_keys()

        timeout_start = time.time()
        print('Connecting ...')
        while (self.ssh_conn != None):
            try:
                self.ssh_conn.connect('127.0.0.1',
                                      username=self.username,
                                      pkey=self.private_key,
                                      port=self.port,
                                      banner_timeout=200)
                break
            except paramiko.ssh_exception.SSHException as exc:
                # socket is open, but not SSH service responded
                if 'Error reading SSH protocol banner' in str(exc):
                    #print('Wait ssh server to be available ...')
                    pass
                else:
                    self.ssh_conn = None
            except TimeoutError as terr:
                pass
            except:
                pass
            if (time.time() >= (timeout_start + timeout)):
                print('Connexion timeout !')
                self.ssh_conn = None
            else:
                time.sleep(self.CONNECT_SLEEP)
        assert self.ssh_conn != None
        print('Connected ...')
        return self.ssh_conn

    def put(self, local_file, remote_file):
        ftp_client=self.ssh_conn.open_sftp()
        ftp_client.put(local_file, remote_file)
        ftp_client.close()

    def get(self, remote_file, local_file):
        ftp_client=self.ssh_conn.open_sftp()
        ftp_client.get(remote_file, local_file)
        ftp_client.close()

    def rsync_file(self, fname, dest, sudo=False):
        """
        fname : local file or folder
        dest : destination folder (parent folder)
        """
        kv_user=self.username
        kv_pass=self.password
        kv_host='127.0.0.1'
        kv_port=self.port
        ssh_opts=f'-i /home/sdp/bprashan/centos_keys/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {kv_port}'
        rsync_opts='-atrv --delete --exclude="*~"'
        # use sshpass to pass clear text password for ssh
        rsync_opts += f' -e " ssh {ssh_opts}"'
        if sudo:
            rsync_opts += ' --rsync-path="sudo rsync"'
        subprocess.check_call(f'rsync {rsync_opts}  {fname} {kv_user}@{kv_host}:{dest}',
                              shell=True,
                              stdout=subprocess.DEVNULL)

    def exec_command(self, cmd):
        """
        Exec a command without checking the return code
        Returns a triple:
        - ret (return code)
        - stdout
        - stderr
        """
        _, stdout, stderr = self.ssh_conn.exec_command(cmd)
        ret_status = stdout.channel.recv_exit_status()
        return ret_status, stdout, stderr

    def check_exec(self, cmd, err_msg=None):
        """
        Exec a command and check the return code
        Returns a 2-tuple:
        - stdout
        - stderr
        """
        _, stdout, stderr = self.ssh_conn.exec_command(cmd)
        if err_msg==None:
            err_msg=f'Execution of {cmd} failed'
        ret_status = stdout.channel.recv_exit_status()
        if ret_status != 0:
            print(stderr.read().decode('utf-8'))
        assert (0 == ret_status), err_msg
        return stdout, stderr

    def poweroff(self):
        _, stdout, _ = self.ssh_conn.exec_command('poweroff')

class QemuMachineService:
    QEMU_MACHINE_PORT_FWD = enum.auto()
    QEMU_MACHINE_MONITOR = enum.auto()
    QEMU_MACHINE_QMP = enum.auto()

# run script to run the guest
# this is used for debugging purpose and allow users
# to run the guest manually
qemu_run_script = """
#!/bin/bash
{cmd_str}
"""
 
class QemuMachine:
    debug_enabled = False
    # hold all qemu instances
    qemu_instances = []

    def __init__(self,
                 name='default',
                 machine=QemuEfiMachine.OVMF_Q35_TDX,
                 memory='2G',
                 service_blacklist=[]):
        self.name = name
        self.image_dir = '/var/tmp/tdxtest/'
        self.guest_initial_img = os.environ.get('TDXTEST_GUEST_IMG', f'{self.image_dir}/tdx-guest.qcow2')
        self._setup_workdir()
        self._create_image()

        # TODO : WA for log, to be removed
        print(f'\n\nQemuMachine created.')

        self.qcmd = QemuCommand(
            self.workdir_name,
            machine,
            memory
            )
        self.qcmd.add_image(self.image_path)
        self.qcmd.add_monitor()
        # monitor client associated to this machine
        # since there could be only one client, we keep track
        # of this client instance in the qemu machine object
        self.monitor = None
        self.qcmd.add_qmp()
        if QemuMachineService.QEMU_MACHINE_PORT_FWD not in service_blacklist:
            self.fwd_port = util.tcp_port_available()
            self.qcmd.add_port_forward(self.fwd_port)
        self.qcmd.add_qemu_run_log()

        self.proc = None
        self.out = None
        self.err = None

        QemuMachine.qemu_instances.append(self)

    @staticmethod
    def is_debug_enabled():
        return QemuMachine.debug_enabled

    @staticmethod
    def set_debug(debug : bool):
        QemuMachine.debug_enabled = debug

    @staticmethod
    def stop_all_running_qemus():
        for qemu in QemuMachine.qemu_instances:
            qemu.stop()

    def _create_image(self):
        # create an overlay image backed by the original image
        # See https://wiki.qemu.org/Documentation/CreateSnapshot
        self.image_path=f'{self.workdir_name}/image.qcow2'
        subprocess.check_call(f'cp -f {self.guest_initial_img} {self.image_path}',
                              stdout=subprocess.DEVNULL,
                              shell=True)

    def _setup_workdir(self):
        # if /run/user/ user folder exists, use it to store the work dir
        # if not use the default path for tempfile that is /tmp/
        run_path = pathlib.Path('/run/user/%d/' % (os.getuid()))
        if run_path.exists():
            tempfile.tempdir = str(run_path)
        # delete=False : we want to manage cleanup ourself for debugging purposes
        # delete parameter is only available from 3.12
        if (sys.version_info[0]==3) and (sys.version_info[1]>11):
            self.workdir = tempfile.TemporaryDirectory(prefix=f'tdxtest-{self.name}-', delete=False)
        else:
            self.workdir = tempfile.TemporaryDirectory(prefix=f'tdxtest-{self.name}-')
        self.workdir_name = self.workdir.name

    @property
    def pid(self):
        cs = subprocess.run(['cat', f'{self.workdir.name}/qemu.pid'], capture_output=True)
        assert cs.returncode == 0, 'Failed getting qemu pid'
        pid = int(cs.stdout.strip())
        return pid

    def rsync_file(self, fname, dest, sudo=False):
        """
        fname : local file or folder
        dest : destination folder (parent folder)
        """
        kv_user='root'
        kv_host='127.0.0.1'
        kv_port=self.fwd_port
        ssh_opts=f'-i /home/sdp/bprashan/centos_keys/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {kv_port}'
        rsync_opts='-atrv --delete --exclude="*~"'
        # use sshpass to pass clear text password for ssh
        rsync_opts += f' -e "ssh {ssh_opts}"'
        if sudo:
            rsync_opts += ' --rsync-path="sudo rsync"'
        subprocess.check_call(f'rsync {rsync_opts}  {fname} {kv_user}@{kv_host}:{dest}',
                              shell=True,
                              stdout=subprocess.DEVNULL)

    def run(self):
        """
        Run qemu
        """
        cmd = self.qcmd.get_command()
        print(' '.join(cmd))
        script=f'{self.workdir_name}/run.sh'
        self.write_cmd_to_file(script)
        print(f'Run script : {cmd}')
        self.proc = subprocess.Popen(cmd,
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE)

    def run_and_wait(self):
        """
        Run qemu and wait for its start (by waiting for monitor file's availability)
        """
        self.run()
        QemuMonitor(self)

    def communicate(self, timeout=60):
        """
        Wait for qemu to exit
        """
        self.out, self.err = self.proc.communicate(timeout=timeout)
        if self.proc.returncode != 0:
            print(self.err.decode())
        return self.out, self.err

    def shutdown(self):
        """
        Send shutdown command to the VM
        Do not wait for the VM to exit
        Return false if the VM is already terminated
        """
        if self.proc is None:
            return False
        if self.proc.returncode is not None:
            return False

        try:
            mon = QemuMonitor(self)
            mon.powerdown()
        except Exception as e:
            pass

        return True

    def stop(self):
        """
        Stop qemu process
        """
        if not self.shutdown():
            return

        try:
            # try to shutdown the VM properly, this is important to avoid
            # rootfs corruption if we want to run the guest again
            # catch exception and ignore it since we are stopping .... no need to fail the test
            self.communicate()
            return
        except Exception as e:
            pass

        print(f'Qemu process did not shutdown properly, terminate it ... ({self.workdir_name})')
        # terminate qemu process (SIGTERM)
        try:
            self.proc.terminate()
            self.communicate()
        except Exception as e:
            print(f'Exception {e}')

    def reboot(self):
        """
        Reboot the QEMU machine
        Since VM might not support reboot just poweroff and start gain
        """
        m = QemuSSH(self)
        # sync data and poweroff
        m.check_exec('sync && systemctl poweroff')
        # check that VM quits properly
        self.communicate()
        # run the VM again
        self.run()

    def write_cmd_to_file(self, fname : str):
        """
        Write the qemu command to a executable bash script
        """
        # force -serial to stdio to be able to have the console on stdio
        cur_serial = self.qcmd.plugins['serial']
        self.qcmd.plugins['serial'] = QemuSerial()

        cmd = self.qcmd.get_command()
        with open(fname, 'w+') as run_script:
            cmd_str=''
            for el in cmd:
                # escape qemu object with quotes
                # for example : -object "{'qom-type': 'tdx-guest', 'id': 'tdx'}"
                if el.startswith('{') and el.endswith('}'):
                    cmd_str += f'\"{el}\" '
                else:
                    cmd_str += f'{el} '
                script_contents = qemu_run_script.format(cmd_str=cmd_str)
            run_script.write(script_contents)
        f = pathlib.Path(fname)
        f.chmod(f.stat().st_mode | stat.S_IEXEC)

        # restore serial config
        self.qcmd.plugins['serial'] = cur_serial

    def __del__(self):
        """
        Make sure we stop the qemu process if it is still running
        and clean up the working dir
        """
        self.stop()
        needs_cleanup = (not QemuMachine.is_debug_enabled())
        if needs_cleanup:
            self.workdir.cleanup()

        QemuMachine.qemu_instances.remove(self)

    def __enter__(self):
        """
        Context manager enter function
        """
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        """
        Context manager exit function
        On context exit, we only stop the qemu process
        Other cleanup (workdir) is still delegated to object destruction hook, this is
        useful if we want to avoid these cleanup actions (test failure, debug flag, ...)
        """
        self.stop()
