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
        self.nb_cores=16
        self.nb_sockets=1
    def args(self):
        smp = ['-smp', f'{self.nb_cores},sockets={self.nb_sockets}']
        if self.cpu_flags != '':
            cpu = ['-cpu', self.cpu_type, self.cpu_flags]
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
        self.bios_path = '/usr/share/ovmf/OVMF.fd'
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
            '-object', 'tdx-guest,id=tdx',
            '-machine', 'q35,kernel_irqchip=split,confidential-guest-support=tdx']
    }
    def __init__(self, machine = QemuEfiMachine.OVMF_Q35_TDX):
        self.machine = machine
    def args(self):
        return self.Qemu_Machine_Params[self.machine]

class QemuBootType:
    def __init__(self,
                 image_path=None,
                 kernel=None,
                 initrd=None):
        self.image_path = image_path
        self.kernel = kernel
        self.initrd = initrd

    def args(self):
        _args = []
        if self.kernel:
            _args.extend(['-kernel', self.kernel])
            _args.extend(['-append', '"root=/dev/vda1 console=ttyS0"'])
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
                        'machine' : QemuMachineType(machine)}
        self.command = ['-pidfile', f'{self.workdir}/qemu.pid']

    def get_command(self):
        _args = ['qemu-system-x86_64']
        for p in self.plugins.values():
            _args.extend(p.args())
        return _args + self.command

    def add_serial_to_file(self):
        # serial to file
        self.command = self.command + [
            '-chardev', f'file,id=c1,path={self.workdir}/serial.log,signal=off',
            '-device', 'isa-serial,chardev=c1'
        ]

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
        return self.monitor_file

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
                print(f'Try to connect to qemu : {qemu.qcmd.monitor_file} : {e}')
                time.sleep(1)
        self.socket.settimeout(self.READ_TIMEOUT)

    def recv(self):
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
                break
            for m in msgs:
                if s in m:
                    return True
        raise RuntimeError('Check state failed : %s' % (s))

    def wakeup(self):
        self.send_command("system_wakeup")

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
                                      password=self.password,
                                      port=self.port)
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
        ssh_opts=f'-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {kv_port}'
        rsync_opts='-atrv --delete --exclude="*~"'
        # use sshpass to pass clear text password for ssh
        rsync_opts += f' -e "sshpass -p {kv_pass} ssh {ssh_opts}"'
        if sudo:
            rsync_opts += ' --rsync-path="sudo rsync"'
        subprocess.check_call(f'rsync {rsync_opts}  {fname} {kv_user}@{kv_host}:{dest}',
                              shell=True,
                              stdout=subprocess.DEVNULL)

    def check_exec(self, cmd, err_msg=None):
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

class QemuMachine:
    def __init__(self,
                 name='default',
                 machine=QemuEfiMachine.OVMF_Q35_TDX,
                 memory='2G',
                 service_blacklist=[]):
        self.name = name
        self.debug = os.environ.get('TDXTEST_DEBUG', False)
        self.image_dir = '/var/tmp/tdxtest/'
        self.guest_initial_img = os.environ.get('TDXTEST_GUEST_IMG', f'{self.image_dir}/tdx-guest.qcow2')
        self._setup_workdir()
        self._create_image()

        # TODO : WA for log, to be removed
        print(f'\n\nQemuMachine created (debug={self.debug}).')

        self.qcmd = QemuCommand(
            self.workdir_name,
            machine,
            memory
            )
        self.qcmd.add_image(self.image_path)
        self.qcmd.add_monitor()
        self.qcmd.add_qmp()
        if QemuMachineService.QEMU_MACHINE_PORT_FWD not in service_blacklist:
            self.fwd_port = util.tcp_port_available()
            self.qcmd.add_port_forward(self.fwd_port)
        self.qcmd.add_qemu_run_log()
        self.qcmd.add_serial_to_file()

        self.proc = None
        self.out = None
        self.err = None

    def _create_image(self):
        # create an overlay image backed by the original image
        # See https://wiki.qemu.org/Documentation/CreateSnapshot
        self.image_path=f'{self.workdir_name}/image.qcow2'
        subprocess.check_call(f'qemu-img create -f qcow2 -b {self.guest_initial_img} -F qcow2 {self.image_path}',
                              stdout=subprocess.DEVNULL,
                              shell=True)

    def _setup_workdir(self):
        run_path = pathlib.Path('/run/user/%d/' % (os.getuid()))
        if run_path.exists():
            tempfile.tempdir = str(run_path)
        # delete parameter is only available from 3.12
        if (sys.version_info[0]==3) and (sys.version_info[1]>11):
            self.workdir = tempfile.TemporaryDirectory(prefix=f'tdxtest-{self.name}-', delete=not self.debug)
        else:
            self.workdir = tempfile.TemporaryDirectory(prefix=f'tdxtest-{self.name}-')
        self.workdir_name = self.workdir.name

    def rsync_file(self, fname, dest, sudo=False):
        """
        fname : local file or folder
        dest : destination folder (parent folder)
        """
        kv_user='root'
        kv_host='127.0.0.1'
        kv_port=self.fwd_port
        ssh_opts=f'-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {kv_port}'
        rsync_opts='-atrv --delete --exclude="*~"'
        # use sshpass to pass clear text password for ssh
        rsync_opts += f' -e "sshpass -p 123456 ssh {ssh_opts}"'
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
        self.proc = subprocess.Popen(cmd,
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE)

    def communicate(self):
        """
        Wait for qemu to exit
        """
        self.out, self.err = self.proc.communicate()
        if self.proc.returncode != 0:
            print(self.err.decode())
        return self.out, self.err

    def stop(self):
        """
        Stop qemu
        """
        # self.proc.returncode== None -> not yet terminated
        if self.proc.returncode is None:
            try:
                self.proc.terminate()
                self.communicate()
            except Exception as e:
                print(f'Exception {e}')

    def __del__(self):
        """
        Make sure we stop the qemu process and clean up the working dir
        """
        self.stop()
        if not self.debug:
            self.workdir.cleanup()
