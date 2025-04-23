# #!/usr/bin/env python3
# #
# # Copyright 2024 Canonical Ltd.
# #
# # This program is free software: you can redistribute it and/or modify it
# # under the terms of the GNU General Public License version 3, as published
# # by the Free Software Foundation.
# #
# # This program is distributed in the hope that it will be useful, but WITHOUT
# # ANY WARRANTY; without even the implied warranties of MERCHANTABILITY,
# # SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# # General Public License for more details.
# #
# # You should have received a copy of the GNU General Public License along with
# # this program.  If not, see <http://www.gnu.org/licenses/>.
# #

# import os
# import time
# import json
# import subprocess
# import pytest

# import Qemu
# import util

# ubuntu_codename = None

# @pytest.mark.quote_generation
# def test_guest_measurement_trust_authority_success():
#     """
#     Trust Authority CLI quote generation success
#     """
#     change_qgsd_state('start')
#     quote_str = run_trust_authority()
#     print(quote_str)
#     check_ita_output(quote_str, for_success = True)

# @pytest.mark.quote_generation
# def test_guest_measurement_trust_authority_failure():
#     """
#     Trust Authority CLI quote generation failure
#     """
#     change_qgsd_state('stop')
#     quote_str = run_trust_authority()
#     change_qgsd_state('start')
#     check_ita_output(quote_str, for_success = False)

# def change_qgsd_state(state):
#     cmd = ['systemctl', state, 'qgsd']
#     subprocess.run(cmd)
#     rc = subprocess.run(cmd, stderr=subprocess.STDOUT, timeout=30)
#     assert 0 == rc.returncode, 'Failed change state of qgsd'

# def check_ita_output(quote_str : str, for_success : bool = True):
#     """
#     Check the validity of ITA quote output
#     Depending on the version of the ITA client, the output
#     may vary:
#     - Ubuntu 24.04 (ITA 1.5.0)
#       On success: [4 0 2 0 129 0 0 ... 0 0 0 0 0 ]
#       On failure: []
#     - Ubuntu 24.10 (ITA 1.6.1)
#       On success:
#         Quote: <base64_encoded_quote>
#         runtime_data: base64_encoded_runtime_data <- Optional
#         user_data: base64_encoded_user_data <- Optional
#       On failure:
#         Quote:
#     """
#     # regex to check the output of ITA quote command, the regex depends on ITA version
#     # for the moment, we extract the ITA version from the ubuntu release
#     # {10,0}: check for at least 10 characters to declare the quote valid
#     ita_output_regexp = r"Successfully get the TD Quote\s*Wrote TD Quote to quote.dat\s*"

#     import re
#     pattern = re.compile(ita_output_regexp)
#     assert (bool(pattern.search(quote_str)) == for_success), f'Error on quote generation: {quote_str}'

# def run_trust_authority():
#     global ubuntu_codename

#     quote_str = ""
#     with Qemu.QemuMachine() as qm:
#         machine = qm.qcmd.plugins['machine']
#         machine.enable_qgs_addr()

#         qm.run()

#         ssh = Qemu.QemuSSH(qm)

#         # stdout, _ = ssh.check_exec('lsb_release -cs')
#         # ubuntu_codename = stdout.read().decode().strip()
#         ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && make clean && make')
#         try:
#           stdout, stderr = ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && ./test_tdx_attest')
#           quote_str = stdout.read().decode()
#         except AssertionError as e:
#           print(f"AssertionError: {e}")
#     return quote_str
