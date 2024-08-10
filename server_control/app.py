import json
import os
from flask import Flask, render_template, request, redirect, url_for, flash, Response
import subprocess
import threading
import time
from cryptography.fernet import Fernet

app = Flask(__name__)
app.secret_key = '906dce92e75e3427ce2052e49d0a0091'

# Path to the encrypted JSON file
encrypted_file = 'servers.json.enc'
# Generate or load the encryption key
key_file = 'secret.key'

if os.path.exists(key_file):
    with open(key_file, 'rb') as f:
        encryption_key = f.read()
else:
    encryption_key = Fernet.generate_key()
    with open(key_file, 'wb') as f:
        f.write(encryption_key)

cipher = Fernet(encryption_key)

# In-memory database for servers
servers = []

def load_servers():
    if os.path.exists(encrypted_file):
        with open(encrypted_file, 'rb') as f:
            encrypted_data = f.read()
            decrypted_data = cipher.decrypt(encrypted_data)
            global servers
            servers = json.loads(decrypted_data.decode('utf-8'))

def save_servers():
    with open(encrypted_file, 'wb') as f:
        json_data = json.dumps(servers).encode('utf-8')
        encrypted_data = cipher.encrypt(json_data)
        f.write(encrypted_data)

def fetch_sensor_data(server_id):
    server = servers[server_id]
    method = server['method']
    ip = server['ip']
    username = server['username']
    password = server['password']
    
    if method == 'ipmi':
        command = f"./servercontrol.sh ipmi sensor_data -i {ip} -u {username} -p {password}"
    elif method == 'snmp':
        community = server.get('community')
        oid = server.get('oid')
        version = server.get('version')
        command = f"./servercontrol.sh snmp sensor_data -a {ip} -c {community} -s {oid} -v {version} -d"
    elif method == 'redfish':
        command = f"./servercontrol.sh redfish sensor_data -r {ip} -u {username} -p {password} -d"
    
    try:
        result = subprocess.check_output(command, shell=True).decode('utf-8').strip()
        return result
    except subprocess.CalledProcessError:
        return "Failed to retrieve sensor data"

def generate_sensor_data():
    while True:
        for idx in range(len(servers)):
            data = fetch_sensor_data(idx)
            # Escape special characters
            escaped_data = data.replace('\n', '\\n').replace('"', '\\"')
            # Format the data as JSON
            yield f"data: {{\"server_id\": {idx}, \"data\": \"{escaped_data}\"}}\n\n"
            time.sleep(10)

@app.route('/')
def index():
    return render_template('index.html', servers=servers)

@app.route('/add_server', methods=['POST'])
def add_server():
    name = request.form['name']
    method = request.form['method']
    ip = request.form['ip']
    username = request.form['username']
    password = request.form['password']
    
    server = {
        'name': name,
        'method': method,
        'ip': ip,
        'username': username,
        'password': password,
        'sensor_data': ''
    }
    servers.append(server)
    save_servers()
    flash(f'Server {name} added successfully!')
    return redirect(url_for('index'))

@app.route('/control/<int:server_id>/<action>', methods=['POST'])
def control(server_id, action):
    server = servers[server_id]
    method = server['method']
    ip = server['ip']
    username = server['username']
    password = server['password']

    if method == 'ipmi':
        command = f"./servercontrol.sh ipmi {action} -i {ip} -u {username} -p {password}"
    elif method == 'snmp':
        community = request.form['community']
        oid = request.form['oid']
        version = request.form['version']
        value = request.form.get('value', '')
        command = f"./servercontrol.sh snmp {action} -a {ip} -c {community} -s {oid} -v {version}"
        if value:
            command += f" -o {value}"
    elif method == 'redfish':
        command = f"./servercontrol.sh redfish {action} -r {ip} -u {username} -p {password}"
    
    try:
        subprocess.run(command, shell=True, check=True)
        flash(f'Action {action} executed successfully on server {server["name"]}!')
    except subprocess.CalledProcessError:
        flash(f'Failed to execute {action} on server {server["name"]}.', 'error')
    
    return redirect(url_for('index'))

@app.route('/events')
def events():
    return Response(generate_sensor_data(), content_type='text/event-stream')

@app.route('/fetch_sensor_data/<int:server_id>')
def fetch_sensor_data_route(server_id):
    data = fetch_sensor_data(server_id)
    return {'sensor_data': data}

if __name__ == '__main__':
    load_servers()  # Load server data when the application starts
    app.run(debug=True)
