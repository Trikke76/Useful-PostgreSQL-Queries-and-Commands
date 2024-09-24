import subprocess
import sys
import time

def run_ssh_command(hostname, username, command):
    ssh_command = [
        "ssh",
        "-o", "StrictHostKeyChecking=no",
        f"{username}@{hostname}",
        command
    ]
    
    try:
        result = subprocess.run(ssh_command, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error (exit code {e.returncode}): {e.stdout.strip()}\n{e.stderr.strip()}"

def run_local_command(command):
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error (exit code {e.returncode}): {e.stdout.strip()}\n{e.stderr.strip()}"

def check_service_status(hostname, username):
    return run_ssh_command(hostname, username, "sudo systemctl is-active postgresql-14.service || echo 'inactive'")

def check_path_exists(hostname, username, path):
    result = run_ssh_command(hostname, username, f"sudo test -d {path} && echo 'exists' || echo 'not found'")
    return result == "exists"

def remove_data(hostname, username, path):
    print(f"Removing all data in {path}...")
    return run_ssh_command(hostname, username, f"sudo rm -rf {path}/*")

def main():
    # Define variables for source and target servers
    source_server = "<source db server>"
    target_server = "<target db server>"  # This is also the hostname we connect to
    
    username = "postgres"
    data_path = "/var/lib/pgsql/14/data"

    # Check initial service status
    initial_status = check_service_status(target_server, username)
    print(f"Initial postgresql-14.service status: {initial_status}")

    if initial_status == "active":
        print("Attempting to stop the service...")
        stop_result = run_ssh_command(target_server, username, "sudo systemctl stop postgresql-14.service")
        print(f"Stop command result: {stop_result}")

        # Check status after stop attempt
        new_status = check_service_status(target_server, username)
        print(f"New postgresql-14.service status: {new_status}")

        if new_status != "active":
            print("postgresql-14.service has been successfully stopped.")
        else:
            print("Failed to stop postgresql-14.service. Cannot proceed with data removal.")
            sys.exit(1)

    # Check if the data path exists
    path_exists = check_path_exists(target_server, username, data_path)
    print(f"Status of {data_path}: {'exists' if path_exists else 'not found'}")

    if path_exists:
        # Remove data only if the path exists
        remove_result = remove_data(target_server, username, data_path)
        print(f"Data removal result: {remove_result}")
    else:
        print(f"The path {data_path} does not exist. No data removal performed.")

    # Run Barman recovery command with --jobs 4
    print("\nRunning Barman recovery command with parallel processing...")
    barman_command = f'barman recover --jobs 4 --remote-ssh-command "ssh postgres@{target_server}" {source_server} latest /var/lib/pgsql/14/data'
    barman_result = run_local_command(barman_command)
    print(f"Barman recovery result:\n{barman_result}")

    # Wait for a moment to ensure all operations are complete
    print("Waiting for operations to complete...")
    time.sleep(10)

    # Log back in and perform additional operations
    print("\nLogging back in to perform additional operations...")
    
    # Copy pg_hba.conf and set permissions
    copy_command = "sudo cp /PGSQL/config/pg_hba.conf /var/lib/pgsql/14/data/pg_hba.conf"
    copy_result = run_ssh_command(target_server, username, copy_command)
    print(f"Copy pg_hba.conf result: {copy_result}")

    chmod_command = "sudo chmod 600 /var/lib/pgsql/14/data/pg_hba.conf"
    chmod_result = run_ssh_command(target_server, username, chmod_command)
    print(f"Chmod pg_hba.conf result: {chmod_result}")

    chown_command = "sudo chown postgres:postgres /var/lib/pgsql/14/data/pg_hba.conf"
    chown_result = run_ssh_command(target_server, username, chown_command)
    print(f"Chown pg_hba.conf result: {chown_result}")

    # Verify the file permissions
    verify_command = "ls -l /var/lib/pgsql/14/data/pg_hba.conf"
    verify_result = run_ssh_command(target_server, username, verify_command)
    print(f"Verification of pg_hba.conf permissions:\n{verify_result}")

    # Check if the PostgreSQL service is stopped and start it if necessary
    print("\nChecking PostgreSQL service status...")
    final_status = check_service_status(target_server, username)
    print(f"Current postgresql-14.service status: {final_status}")

    if final_status != "active":
        print("PostgreSQL service is not running. Attempting to start the service...")
        start_result = run_ssh_command(target_server, username, "sudo systemctl start postgresql-14.service")
        print(f"Start command result: {start_result}")

        # Verify the service started successfully
        new_status = check_service_status(target_server, username)
        if new_status == "active":
            print("postgresql-14.service has been successfully started.")
        else:
            print("Failed to start postgresql-14.service. Please check the server logs for more information.")
    else:
        print("PostgreSQL service is already running.")

    print("\nAll operations completed.")

if __name__ == "__main__":
    main()



### Sudo File ###

# Sudo configuration for postgres user
# Allow postgres to run specific commands without a password

# Commands for managing PostgreSQL service
postgres ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop postgresql-14.service
postgres ALL=(ALL) NOPASSWD: /usr/bin/systemctl start postgresql-14.service
postgres ALL=(ALL) NOPASSWD: /usr/bin/systemctl is-active postgresql-14.service

# Commands for file operations
postgres ALL=(ALL) NOPASSWD: /usr/bin/rm -rf /var/lib/pgsql/14/data/*
postgres ALL=(ALL) NOPASSWD: /usr/bin/test -d /var/lib/pgsql/14/data
postgres ALL=(ALL) NOPASSWD: /usr/bin/cp /PGSQL/config/pg_hba.conf /var/lib/pgsql/14/data/pg_hba.conf
postgres ALL=(ALL) NOPASSWD: /usr/bin/chmod 600 /var/lib/pgsql/14/data/pg_hba.conf
postgres ALL=(ALL) NOPASSWD: /usr/bin/chown postgres\:postgres /var/lib/pgsql/14/data/pg_hba.conf
