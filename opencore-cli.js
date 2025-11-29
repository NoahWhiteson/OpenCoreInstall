#!/usr/bin/env node

/**
 * OpenCore CLI Tool
 * Manages OpenCore backend and frontend servers
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Find OpenCore installation directory
function findOpenCoreDir() {
  let currentDir = process.cwd();
  const maxDepth = 10;
  let depth = 0;
  
  // First, check current directory and parents
  while (depth < maxDepth) {
    const backendPath = join(currentDir, 'backend', 'package.json');
    const frontendPath = join(currentDir, 'frontend', 'package.json');
    
    if (fs.existsSync(backendPath) && fs.existsSync(frontendPath)) {
      return currentDir;
    }
    
    const parentDir = join(currentDir, '..');
    if (parentDir === currentDir) break;
    currentDir = parentDir;
    depth++;
  }
  
  // Try common installation paths
  const commonPaths = [
    '/opencore',
    '/opt/opencore',
    join(process.env.HOME || process.env.USERPROFILE || '', 'opencore'),
    join(process.env.HOME || process.env.USERPROFILE || '', 'OpenCore'),
  ];
  
  for (const path of commonPaths) {
    if (fs.existsSync(join(path, 'backend', 'package.json'))) {
      return path;
    }
  }
  
  // Check if we're in an install directory, look for parent
  const installDir = __dirname;
  if (installDir.includes('install')) {
    const parentDir = join(installDir, '..');
    if (fs.existsSync(join(parentDir, 'backend', 'package.json'))) {
      return parentDir;
    }
  }
  
  return null;
}

function getBackendDir(opencoreDir) {
  return join(opencoreDir, 'backend');
}

function getFrontendDir(opencoreDir) {
  return join(opencoreDir, 'frontend');
}

function startBackend(opencoreDir) {
  const backendDir = getBackendDir(opencoreDir);
  console.log(`Starting OpenCore Backend...`);
  console.log(`Directory: ${backendDir}`);
  
  const proc = spawn('npm', ['start'], {
    cwd: backendDir,
    stdio: 'inherit',
    shell: true,
  });
  
  proc.on('error', (err) => {
    console.error(`Failed to start backend: ${err.message}`);
    process.exit(1);
  });
  
  return proc;
}

function startFrontend(opencoreDir) {
  const frontendDir = getFrontendDir(opencoreDir);
  
  // Read port from .env.local if it exists
  let port = '3001';
  const envLocalPath = join(frontendDir, '.env.local');
  if (fs.existsSync(envLocalPath)) {
    const envContent = fs.readFileSync(envLocalPath, 'utf8');
    const portMatch = envContent.match(/PORT=(\d+)/);
    if (portMatch) {
      port = portMatch[1];
    }
  }
  
  console.log(`Starting OpenCore Frontend on port ${port}...`);
  console.log(`Directory: ${frontendDir}`);
  
  const proc = spawn('npm', ['start'], {
    cwd: frontendDir,
    stdio: 'inherit',
    shell: true,
    env: { ...process.env, PORT: port },
  });
  
  proc.on('error', (err) => {
    console.error(`Failed to start frontend: ${err.message}`);
    process.exit(1);
  });
  
  return proc;
}

function stopProcess(processName) {
  console.log(`Stopping ${processName}...`);
  
  const isWindows = process.platform === 'win32';
  const command = isWindows ? 'taskkill' : 'pkill';
  const args = isWindows 
    ? ['/F', '/IM', 'node.exe', '/FI', `WINDOWTITLE eq *${processName}*`]
    : ['-f', processName];
  
  const proc = spawn(command, args, {
    stdio: 'inherit',
    shell: true,
  });
  
  proc.on('error', (err) => {
    console.error(`Failed to stop ${processName}: ${err.message}`);
  });
  
  proc.on('exit', (code) => {
    if (code === 0) {
      console.log(`${processName} stopped successfully`);
    } else {
      console.log(`No running ${processName} process found`);
    }
  });
}

// Main CLI handler
const command = process.argv[2];
const subcommand = process.argv[3];

if (!command) {
  console.log(`
OpenCore CLI - System Monitoring Platform

Usage:
  opencore <command> [options]

Commands:
  backend start    Start the backend server
  backend stop     Stop the backend server
  frontend start   Start the frontend server
  frontend stop    Stop the frontend server
  start            Start both backend and frontend
  stop             Stop both backend and frontend

Examples:
  opencore backend start
  opencore frontend start
  opencore backend stop
  opencore frontend stop
  opencore start
  opencore stop
`);
  process.exit(0);
}

const opencoreDir = findOpenCoreDir();

if (!opencoreDir) {
  console.error('Error: Could not find OpenCore installation directory.');
  console.error('Please run this command from within the OpenCore directory or ensure OpenCore is installed.');
  process.exit(1);
}

// Handle commands
if (command === 'backend') {
  if (subcommand === 'start') {
    startBackend(opencoreDir);
  } else if (subcommand === 'stop') {
    stopProcess('opencore-backend');
  } else {
    console.error(`Unknown backend command: ${subcommand}`);
    console.error('Use: opencore backend [start|stop]');
    process.exit(1);
  }
} else if (command === 'frontend') {
  if (subcommand === 'start') {
    startFrontend(opencoreDir);
  } else if (subcommand === 'stop') {
    stopProcess('opencore-frontend');
  } else {
    console.error(`Unknown frontend command: ${subcommand}`);
    console.error('Use: opencore frontend [start|stop]');
    process.exit(1);
  }
} else if (command === 'start') {
  console.log('Starting both backend and frontend...');
  startBackend(opencoreDir);
  setTimeout(() => {
    startFrontend(opencoreDir);
  }, 2000);
} else if (command === 'stop') {
  stopProcess('opencore-backend');
  stopProcess('opencore-frontend');
} else {
  console.error(`Unknown command: ${command}`);
  console.error('Use: opencore [backend|frontend|start|stop]');
  process.exit(1);
}

