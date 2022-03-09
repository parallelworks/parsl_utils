from subprocess import Popen, PIPE, STDOUT
import sys

# Run and log a command using Popen
def run_and_log_cmd(cmd):
    print('\n\nRunning command:\n' + cmd, flush = True)
    process = Popen(cmd, stdout = PIPE, stderr = PIPE, shell = True)

    # Initialize logging loop:
    for line in iter(process.stdout.readline, '\n'):
        if process.poll() == None:
            line_str = line.decode('utf-8').rstrip()
            print(line_str, flush = True)
        elif process.poll() == 0:
            print('Command finished successfully', flush = True)
            break
        else:
            msg = 'Command failed or killed'
            print(msg, flush = True)
            for line in process.stderr.readlines():
                sys.stderr.write(line.decode('utf-8').rstrip())
            break
