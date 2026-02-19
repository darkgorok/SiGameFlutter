/* eslint-disable no-console */
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const HOST = '127.0.0.1';
const PORT = 8080;
const PROJECT_ID = 'demo-si-game';

function findFirestoreJar() {
  const emulatorsDir = path.join(os.homedir(), '.cache', 'firebase', 'emulators');
  if (!fs.existsSync(emulatorsDir)) {
    return null;
  }
  const candidates = fs
    .readdirSync(emulatorsDir)
    .filter((name) => /^cloud-firestore-emulator-v.+\.jar$/.test(name))
    .sort();
  if (candidates.length === 0) {
    return null;
  }
  return path.join(emulatorsDir, candidates[candidates.length - 1]);
}

function waitForPort(host, port, timeoutMs) {
  const started = Date.now();
  return new Promise((resolve, reject) => {
    const check = () => {
      const socket = net.createConnection({ host, port });
      socket.once('connect', () => {
        socket.destroy();
        resolve();
      });
      socket.once('error', () => {
        socket.destroy();
        if (Date.now() - started >= timeoutMs) {
          reject(new Error(`Timed out waiting for ${host}:${port}`));
          return;
        }
        setTimeout(check, 250);
      });
    };
    check();
  });
}

function runCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: 'inherit',
      shell: false,
      ...options,
    });
    child.once('error', reject);
    child.once('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${command} exited with code ${code}`));
    });
  });
}

function findJdk21BinDir() {
  const envJavaHome = process.env.JAVA_HOME;
  if (envJavaHome) {
    const bin = path.join(envJavaHome, 'bin');
    if (fs.existsSync(path.join(bin, 'java.exe')) || fs.existsSync(path.join(bin, 'java'))) {
      return bin;
    }
  }

  const adoptiumDir = path.join(process.env.ProgramFiles || 'C:\\Program Files', 'Eclipse Adoptium');
  if (!fs.existsSync(adoptiumDir)) {
    return null;
  }

  const dirs = fs
    .readdirSync(adoptiumDir)
    .filter((name) => /^jdk-21/i.test(name))
    .sort();
  if (dirs.length === 0) {
    return null;
  }
  const bin = path.join(adoptiumDir, dirs[dirs.length - 1], 'bin');
  if (fs.existsSync(path.join(bin, 'java.exe')) || fs.existsSync(path.join(bin, 'java'))) {
    return bin;
  }
  return null;
}

async function main() {
  const jar = findFirestoreJar();
  if (!jar) {
    console.error('Firestore emulator jar not found. Run: firebase setup:emulators:firestore');
    process.exit(1);
  }

  const jdkBin = findJdk21BinDir();
  if (!jdkBin) {
    console.error('JDK 21 not found. Install Temurin 21 and/or set JAVA_HOME.');
    process.exit(1);
  }

  const env = {
    ...process.env,
    PATH: `${jdkBin}${path.delimiter}${process.env.PATH || ''}`,
    FIRESTORE_EMULATOR_HOST: `${HOST}:${PORT}`,
    FIRESTORE_DATABASE_ID: '(default)',
    GCLOUD_PROJECT: PROJECT_ID,
    GOOGLE_CLOUD_PROJECT: PROJECT_ID,
    FIREBASE_CONFIG: JSON.stringify({ projectId: PROJECT_ID }),
  };

  const javaArgs = ['-jar', jar, '--host', HOST, '--port', String(PORT)];
  const emulator = spawn('java', javaArgs, {
    stdio: ['ignore', 'pipe', 'pipe'],
    detached: false,
    shell: false,
    env,
  });
  emulator.stdout.on('data', () => {});
  emulator.stderr.on('data', () => {});

  const stopEmulator = () => {
    if (!emulator.killed) {
      emulator.kill('SIGTERM');
    }
  };

  process.on('SIGINT', () => {
    stopEmulator();
    process.exit(130);
  });
  process.on('SIGTERM', () => {
    stopEmulator();
    process.exit(143);
  });

  try {
    const exitedEarly = await Promise.race([
      waitForPort(HOST, PORT, 30000).then(() => false),
      new Promise((resolve) => emulator.once('exit', () => resolve(true))),
    ]);
    if (exitedEarly) {
      throw new Error('Firestore emulator failed to start (java exited early)');
    }

    await runCommand('node', ['--test', 'tests/*.emulator.test.js'], {
      cwd: path.resolve(__dirname, '..'),
      env,
    });
  } finally {
    stopEmulator();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
