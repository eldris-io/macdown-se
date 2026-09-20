#!/usr/bin/env python3
"""Live MCP UAT. Requires a GUI login session; refuses to touch an existing app.

Usage: python3 scripts/test_mcp.py --app '/path/to/MacDown SE.app'
Add --auto-launch to test the CLI's cold-start path, or --leaks for Apple's leaks scan.
"""
import argparse
import json
import os
from pathlib import Path
import select
import socket as sockets
import subprocess
import time


def pids():
    output = subprocess.run(['pgrep', '-x', 'MacDown SE'], capture_output=True, text=True).stdout
    return [int(p) for p in output.split()]


class Client:
    def __init__(self, executable):
        self.process = subprocess.Popen([str(executable), '--mcp'], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.buffer = b''
        self.identifier = 0

    def send(self, value):
        self.process.stdin.write((json.dumps(value) + '\n').encode())
        self.process.stdin.flush()

    def read(self):
        deadline = time.monotonic() + 30
        while b'\n' not in self.buffer:
            remaining = deadline - time.monotonic()
            assert remaining > 0 and select.select([self.process.stdout], [], [], remaining)[0], 'MCP response timeout'
            data = os.read(self.process.stdout.fileno(), 65536)
            assert data, 'MCP exited without a response'
            self.buffer += data
        line, self.buffer = self.buffer.split(b'\n', 1)
        return json.loads(line)

    def call(self, method, params=None, error=None):
        self.identifier += 1
        self.send(dict(jsonrpc='2.0', id=self.identifier, method=method, params=params or {}))
        reply = self.read()
        assert reply['id'] == self.identifier and reply['jsonrpc'] == '2.0', reply
        print(json.dumps(dict(method=method, response=reply), ensure_ascii=False), flush=True)
        if error is not None:
            assert reply['error']['code'] == error, reply
            return reply
        assert 'error' not in reply, reply
        return reply['result']

    def tool(self, name, arguments=None):
        result = self.call('tools/call', dict(name='macdown_' + name, arguments=arguments or {}))
        assert not result['isError'], result
        text = result['content'][0]['text']
        return text if name == 'render_preview' else json.loads(text)

    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=10)
        assert self.process.returncode == 0
        diagnostics = self.process.stderr.read().decode()
        assert not diagnostics, diagnostics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--auto-launch', action='store_true')
    parser.add_argument('--leaks', action='store_true')
    args = parser.parse_args()
    app = args.app.resolve()
    assert not pids(), 'Quit MacDown SE before running UAT; existing documents are never closed.'
    helper = app / 'Contents/SharedSupport/bin/macdown-se'
    executable = app / 'Contents/MacOS/MacDown SE'
    assert helper.is_file() and executable.is_file()
    assert (helper.parent / 'macdown').is_symlink()
    start = time.time()
    socket = Path.home() / 'Library/Application Support/MacDown SE/macdown_se.sock'
    reports = [Path.home() / 'Library/Logs/DiagnosticReports', Path('/Library/Logs/DiagnosticReports')]
    app_process = None
    client = None
    try:
        if not args.auto_launch:
            app_process = subprocess.Popen([str(executable)], stdout=open("/private/tmp/macdown-mcp-gui.log", "w"), stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                assert app_process.poll() is None, 'App exited on launch'
                try:
                    with sockets.socket(sockets.AF_UNIX) as probe:
                        probe.connect(str(socket))
                    break
                except OSError:
                    time.sleep(.1)
            else:
                raise AssertionError('Socket did not become ready')
        client = Client(helper)
        client.call('tools/list', error=-32002)
        result = client.call('initialize', dict(protocolVersion='2024-11-05', capabilities={},
                                                clientInfo=dict(name='macdown-live-uat', version='1')))
        assert result == dict(protocolVersion='2024-11-05', serverInfo=dict(name='macdown-se', version='1.0.0'), capabilities=dict(tools={}, resources={}))
        assert pids(), 'Helper startup did not launch the GUI'
        client.send(dict(jsonrpc='2.0', method='notifications/initialized'))
        assert len(client.call('tools/list')['tools']) == 5
        assert client.call('resources/list')['resources'][0]['uri'] == 'macdown://active'
        original = '# MCP live test\n\nNative **Markdown** — café 🌍\n'
        document = client.tool('new_document', dict(markdown=original))
        assert document['content'] == original and document['isDirty']
        active = client.tool('get_active_document')
        assert active['content'] == original and active['path'] is None
        addition = '\nInserted by MCP.\n'
        document = client.tool('insert_at_cursor', dict(text=addition))
        assert document['content'] == original + addition
        document = client.tool('replace_selection', dict(text='Replacement at caret.'))
        assert document['content'] == original + addition + 'Replacement at caret.'
        assert client.tool('get_active_document')['content'] == document['content']
        assert client.call('resources/read', dict(uri='macdown://active'))['contents'][0]['text'] == document['content']
        html = client.tool('render_preview', dict(markdown='# Native heading\n\n**bold** & <tag>\n'))
        assert '<h1' in html and 'Native heading</h1>' in html and '<strong>bold</strong>' in html
        assert client.tool('get_active_document')['content'] == document['content'], 'Rendering changed editor'
        client.call('tools/call', dict(name='macdown_insert_at_cursor', arguments=dict(text=42)), error=-32602)
        client.call('tools/call', dict(name='unknown'), error=-32602)
        client.call('resources/read', dict(uri='macdown://unknown'), error=-32602)
        client.call('unknown', error=-32601)
        client.process.stdin.write(b'{broken\n'); client.process.stdin.flush()
        assert client.read()['error']['code'] == -32700
        client.call('ping')
        subprocess.run(['osascript', '-e', 'tell application id "io.eldris.macdown-se" to close every document saving no'], check=True, timeout=15)
        empty = client.call('tools/call', dict(name='macdown_get_active_document', arguments={}))
        assert empty['isError'] and 'No active' in empty['content'][0]['text']
        assert '<strong>standalone</strong>' in client.tool('render_preview', dict(markdown='**standalone**'))
        running = pids()
        assert len(running) == 1
        pid = running[0]
        command = subprocess.check_output(['ps', '-p', str(pid), '-o', 'command='], text=True).strip()
        assert command == str(executable), command
        print(f'GUI PID {pid}: {command}', flush=True)
        assert socket.stat().st_mode & 0o777 == 0o600
        assert socket.parent.stat().st_mode & 0o777 == 0o700
        if args.leaks:
            time.sleep(3)  # Allow deferred AppKit rendering and startup connections to settle.
            leak_failures = []
            for target in [pid, client.process.pid]:
                scan = subprocess.run(['leaks', str(target)], capture_output=True, text=True)
                print(scan.stdout, flush=True)
                if scan.returncode or '0 leaks for 0 total leaked bytes' not in scan.stdout:
                    leak_failures.append(f'PID {target}: {scan.stderr.strip()}')
            assert not leak_failures, leak_failures
        client.close(); client = None
        assert pids() == running, 'stdio EOF must leave GUI running'
        for directory in reports:
            assert not [p for p in directory.glob('MacDown*') if p.stat().st_mtime >= start], 'New crash report'
        print('PASS: handshake, five tools, resources, validation, live process, permissions, and EOF', flush=True)
    finally:
        if client:
            client.process.terminate(); client.process.wait(timeout=5)
        # Only this script's isolated app exists; discard only its test documents.
        if pids():
            subprocess.run(['osascript', '-e', 'tell application id "io.eldris.macdown-se" to quit saving no'], check=True, timeout=15)
            deadline = time.monotonic() + 10
            while pids() and time.monotonic() < deadline:
                time.sleep(.1)
            assert not pids(), 'GUI failed to terminate'
            assert not socket.exists(), 'Socket was not removed on normal termination'
        if app_process:
            exit_code = app_process.wait(timeout=5)
            print(f'GUI exit status: {exit_code}', flush=True)
            assert exit_code == 0, f'Abnormal GUI exit: {exit_code}'
        print('PASS: clean GUI shutdown and socket cleanup', flush=True)


if __name__ == '__main__':
    main()
