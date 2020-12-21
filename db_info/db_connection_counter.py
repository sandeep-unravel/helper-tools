from __future__ import print_function

import os
import subprocess

unravel_user = os.environ.get('UNRAVEL_USER', 'unravel')
db_host = os.environ.get('DB_HOST', 'localhost')
db_port = os.environ.get('DB_PORT', '3306')

print("Checking for DB connections against {0}:{1} from Unravel processes owned by user '{2}'...\n".format(
    db_host, db_port, unravel_user
))

ps_str = subprocess.Popen("ps aux", stdout=subprocess.PIPE, shell=True).communicate()[0]
ps_lines = [ps_line.split() for ps_line in ps_str.split('\n')]

users = []
pids = []
commands = []

pid_to_command_map = {}

for line in ps_lines[1:]:
    if len(line) > 10 and line[0] == unravel_user:
        user, pid = line[0:2]
        command = ' '.join(line[10:])
        pid_to_command_map[pid] = command

lsof_str = subprocess.Popen("lsof -i @{0}:{1} | grep {2} | grep {3} | tr -s ' ' | cut -d' ' -f2".format(
    db_host,
    db_port,
    unravel_user,
    'ESTABLISHED'
), stdout=subprocess.PIPE, shell=True).communicate()[0]

connected_pids = lsof_str.split()

conn_counter = {}

for connected_pid in connected_pids:
    command = pid_to_command_map.get(connected_pid, 'Unknown')
    ident_idx = command.find("-Dident=")
    if ident_idx >= 0:
        short_command = command[ident_idx + len("-Dident="):].split()[0]
    elif 'node' in command:
        short_command = 'unravel_ngui'
    elif 'celery' in command:
        short_command = 'unravel_ondemand'
    else:
        short_command = command
    conn_counter[short_command] = conn_counter.get(short_command, 0) + 1


new_file = open("db_session.txt", "w")
for process_name, conn_count in conn_counter.items():
    new_line = "{0}: {1}\n".format(process_name, conn_count)
    new_file.write(new_line)

new_file.close()
