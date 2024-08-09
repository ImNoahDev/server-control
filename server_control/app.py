from flask import Flask, render_template, request, redirect, url_for, flash
import subprocess

app = Flask(__name__)
app.secret_key = 'supersecretkey'

# In-memory database for servers
servers = []

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
        'password': password
    }
    servers.append(server)
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

if __name__ == '__main__':
    app.run(debug=True)
