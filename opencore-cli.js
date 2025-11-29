#!/usr/bin/env node

/**
 * OpenCore CLI Tool
 * Manages OpenCore backend and frontend servers
 */

import { spawn, execSync } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs';
import os from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Get config file path
function getConfigPath() {
  const homeDir = os.homedir();
  const configDir = join(homeDir, '.opencore');
  const configFile = join(configDir, 'config.json');
  return { configDir, configFile };
}

// Save OpenCore installation location
function saveInstallLocation(opencoreDir) {
  try {
    const { configDir, configFile } = getConfigPath();
    if (!fs.existsSync(configDir)) {
      fs.mkdirSync(configDir, { recursive: true });
    }
    const config = {
      installPath: opencoreDir,
      updatedAt: new Date().toISOString()
    };
    fs.writeFileSync(configFile, JSON.stringify(config, null, 2), 'utf8');
    return true;
  } catch (error) {
    console.error('Error saving install location:', error);
    return false;
  }
}

// Load OpenCore installation location from config
function loadInstallLocation() {
  try {
    const { configFile } = getConfigPath();
    if (fs.existsSync(configFile)) {
      const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
      if (config.installPath && fs.existsSync(join(config.installPath, 'backend', 'package.json'))) {
        return config.installPath;
      }
    }
  } catch (error) {
    // Config file doesn't exist or is invalid, continue with search
  }
  return null;
}

// Find OpenCore installation directory
function findOpenCoreDir() {
  // First, try to load from saved config
  const savedLocation = loadInstallLocation();
  if (savedLocation) {
    return savedLocation;
  }
  
  let currentDir = process.cwd();
  const maxDepth = 10;
  let depth = 0;
  
  // Check current directory and parents
  while (depth < maxDepth) {
    const backendPath = join(currentDir, 'backend', 'package.json');
    const frontendPath = join(currentDir, 'frontend', 'package.json');
    
    if (fs.existsSync(backendPath) && fs.existsSync(frontendPath)) {
      // Save this location for future use
      saveInstallLocation(currentDir);
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
      // Save this location for future use
      saveInstallLocation(path);
      return path;
    }
  }
  
  // Check if we're in an install directory, look for parent
  const installDir = __dirname;
  if (installDir.includes('install')) {
    const parentDir = join(installDir, '..');
    if (fs.existsSync(join(parentDir, 'backend', 'package.json'))) {
      saveInstallLocation(parentDir);
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

function startBackend(opencoreDir, background = false) {
  const backendDir = getBackendDir(opencoreDir);
  
  // Always use HOST=0.0.0.0 for backend to listen on all interfaces
  const host = '0.0.0.0';
  
  // Read port from .env if it exists
  let port = '3000';
  const envPath = join(backendDir, '.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    const portMatch = envContent.match(/PORT=(\d+)/);
    if (portMatch) {
      port = portMatch[1];
    }
  }
  
  if (background) {
    const isWindows = process.platform === 'win32';
    const proc = spawn('npm', ['start'], {
      cwd: backendDir,
      stdio: 'ignore',
      detached: !isWindows,
      shell: true,
      env: { 
        ...process.env, 
        HOST: host,
        PORT: port
      },
    });
    
    if (!isWindows) {
      proc.unref();
    }
    
    console.log(`✓ OpenCore Backend started in background on ${host}:${port} (PID: ${proc.pid})`);
    console.log(`  Directory: ${backendDir}`);
    return proc;
  } else {
    console.log(`Starting OpenCore Backend on ${host}:${port}...`);
    console.log(`Directory: ${backendDir}`);
    
    const proc = spawn('npm', ['start'], {
      cwd: backendDir,
      stdio: 'inherit',
      shell: true,
      env: { 
        ...process.env, 
        HOST: host,
        PORT: port
      },
    });
    
    proc.on('error', (err) => {
      console.error(`Failed to start backend: ${err.message}`);
      process.exit(1);
    });
    
    return proc;
  }
}

function startFrontend(opencoreDir, background = false) {
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
  
  if (background) {
    const isWindows = process.platform === 'win32';
    const proc = spawn('npm', ['start'], {
      cwd: frontendDir,
      stdio: 'ignore',
      detached: !isWindows,
      shell: true,
      env: { ...process.env, PORT: port },
    });
    
    if (!isWindows) {
      proc.unref();
    }
    
    console.log(`✓ OpenCore Frontend started in background on port ${port} (PID: ${proc.pid})`);
    console.log(`  Directory: ${frontendDir}`);
    return proc;
  } else {
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
}

function listProcesses() {
  const isWindows = process.platform === 'win32';
  const opencoreDir = findOpenCoreDir();
  
  console.log('\nOpenCore Processes:');
  console.log('==================');
  
  try {
    if (isWindows) {
      // Windows: Use tasklist to find node processes
      const result = execSync('tasklist /FI "IMAGENAME eq node.exe" /FO CSV', { encoding: 'utf8' });
      const lines = result.split('\n').filter(line => line.includes('node.exe'));
      
      let found = false;
      for (const line of lines) {
        const parts = line.split(',');
        if (parts.length >= 2) {
          const pid = parts[1].replace(/"/g, '');
          try {
            const cmdResult = execSync(`wmic process where "ProcessId=${pid}" get CommandLine,ExecutablePath /format:list`, { encoding: 'utf8' });
            const isBackend = cmdResult.includes('backend') && (cmdResult.includes('server.js') || cmdResult.includes('npm start'));
            const isFrontend = cmdResult.includes('frontend') && (cmdResult.includes('next start') || cmdResult.includes('npm start'));
            
            if (isBackend || isFrontend) {
              const type = isBackend ? 'Backend' : 'Frontend';
              // Try to extract port
              const portMatch = cmdResult.match(/PORT[=\s]+(\d+)/i) || cmdResult.match(/:(\d{4,5})/);
              const port = portMatch ? portMatch[1] : '';
              console.log(`${type}: PID ${pid}${port ? ` (Port: ${port})` : ''}`);
              found = true;
            }
          } catch (e) {
            // Ignore
          }
        }
      }
      
      if (!found) {
        console.log('No OpenCore processes found');
      }
    } else {
      // Linux/Mac: Use ps to find node processes and check their working directory
      const result = execSync('ps aux', { encoding: 'utf8' });
      const lines = result.split('\n');
      
      let found = false;
      
      for (const line of lines) {
        if (!line.includes('node') || line.includes('grep') || line.includes('opencore-cli')) continue;
        
        const parts = line.trim().split(/\s+/);
        if (parts.length < 2) continue;
        
        const pid = parts[1];
        const fullCommand = line;
        
        // Get the working directory of the process
        let processCwd = '';
        try {
          processCwd = execSync(`pwdx ${pid} 2>/dev/null || readlink -f /proc/${pid}/cwd 2>/dev/null || echo ''`, { encoding: 'utf8' }).trim();
        } catch (e) {
          // Try alternative method
          try {
            processCwd = execSync(`lsof -p ${pid} 2>/dev/null | grep cwd | awk '{print $NF}' || echo ''`, { encoding: 'utf8' }).trim();
          } catch (e2) {
            // Ignore
          }
        }
        
        // Check if it's a backend process
        const isBackend = (fullCommand.includes('backend') && (fullCommand.includes('server.js') || fullCommand.includes('npm start'))) ||
                         (opencoreDir && (fullCommand.includes(opencoreDir + '/backend') || processCwd.includes('/backend'))) ||
                         (processCwd && processCwd.endsWith('/backend'));
        
        // Check if it's a frontend process
        const isFrontend = (fullCommand.includes('frontend') && (fullCommand.includes('next start') || fullCommand.includes('npm start'))) ||
                          (opencoreDir && (fullCommand.includes(opencoreDir + '/frontend') || processCwd.includes('/frontend'))) ||
                          (processCwd && processCwd.endsWith('/frontend')) ||
                          (fullCommand.includes('next') && fullCommand.includes('start'));
        
        if (isBackend || isFrontend) {
          const type = isBackend ? 'Backend' : 'Frontend';
          
          // Try to extract port from command or check lsof/netstat/ss
          let port = '';
          try {
            // First try to get port from command line
            const portMatch = fullCommand.match(/PORT[=\s]+(\d+)/i) || fullCommand.match(/-p\s+(\d+)/) || fullCommand.match(/:(\d{4,5})/);
            if (portMatch) {
              port = portMatch[1];
            } else {
              // Use lsof/netstat/ss to find the listening port
              try {
                const lsofResult = execSync(`lsof -p ${pid} -iTCP -sTCP:LISTEN -n -P 2>/dev/null | grep LISTEN`, { encoding: 'utf8' });
                const portMatch2 = lsofResult.match(/:(\d{4,5})/);
                if (portMatch2) {
                  port = portMatch2[1];
                }
              } catch (e1) {
                try {
                  const netstatResult = execSync(`netstat -tlnp 2>/dev/null | grep ${pid}`, { encoding: 'utf8' });
                  const portMatch3 = netstatResult.match(/:(\d{4,5})/);
                  if (portMatch3) {
                    port = portMatch3[1];
                  }
                } catch (e2) {
                  try {
                    const ssResult = execSync(`ss -tlnp 2>/dev/null | grep pid=${pid}`, { encoding: 'utf8' });
                    const portMatch4 = ssResult.match(/:(\d{4,5})/);
                    if (portMatch4) {
                      port = portMatch4[1];
                    }
                  } catch (e3) {
                    // Ignore
                  }
                }
              }
            }
          } catch (e) {
            // Ignore
          }
          
          console.log(`${type}: PID ${pid}${port ? ` (Port: ${port})` : ''}${processCwd ? ` [${processCwd}]` : ''}`);
          found = true;
        }
      }
      
      if (!found) {
        console.log('No OpenCore processes found');
        console.log('Note: Make sure processes are running with "opencore start"');
      }
    }
  } catch (error) {
    console.log('No OpenCore processes found');
  }
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

// Auto-fix CLI permissions and installation
function autoFixCLI() {
  try {
    const isWindows = process.platform === 'win32';
    
    // Fix permissions on the CLI file itself
    if (!isWindows) {
      try {
        execSync(`chmod +x "${__filename}"`, { stdio: 'ignore' });
      } catch (e) {
        // Ignore errors
      }
    }
    
    // Try to find and fix the linked binary
    const npmPaths = [
      '/usr/local/bin/opencore',
      '/usr/bin/opencore',
      join(process.env.HOME || '', '.npm-global/bin/opencore'),
      join(process.env.HOME || '', '.local/bin/opencore'),
    ];
    
    for (const binPath of npmPaths) {
      try {
        if (fs.existsSync(binPath)) {
          if (!isWindows) {
            execSync(`chmod +x "${binPath}"`, { stdio: 'ignore' });
          }
          return true;
        }
      } catch (e) {
        // Continue to next path
      }
    }
    
    // Try to re-link if not found
    try {
      execSync('npm link', { cwd: __dirname, stdio: 'ignore' });
      // Fix permissions after linking
      for (const binPath of npmPaths) {
        try {
          if (fs.existsSync(binPath) && !isWindows) {
            execSync(`chmod +x "${binPath}"`, { stdio: 'ignore' });
          }
        } catch (e) {
          // Ignore
        }
      }
    } catch (e) {
      // Could not auto-link, that's okay
    }
    
    return false;
  } catch (error) {
    return false;
  }
}

// Main CLI handler
const command = process.argv[2];
const subcommand = process.argv[3];

// Auto-fix on startup if there are permission issues
if (process.platform !== 'win32') {
  try {
    // Check if we can execute
    fs.accessSync(__filename, fs.constants.X_OK);
  } catch (e) {
    // Permission denied, try to fix
    autoFixCLI();
  }
}

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
    startBackend(opencoreDir, true); // Run in background
  } else if (subcommand === 'stop') {
    stopProcess('opencore-backend');
  } else {
    console.error(`Unknown backend command: ${subcommand}`);
    console.error('Use: opencore backend [start|stop]');
    process.exit(1);
  }
} else if (command === 'frontend') {
  if (subcommand === 'start') {
    startFrontend(opencoreDir, true); // Run in background
  } else if (subcommand === 'stop') {
    stopProcess('opencore-frontend');
  } else {
    console.error(`Unknown frontend command: ${subcommand}`);
    console.error('Use: opencore frontend [start|stop]');
    process.exit(1);
  }
} else if (command === 'start') {
  console.log('Starting both backend and frontend...');
  startBackend(opencoreDir, true); // Run in background
  setTimeout(() => {
    startFrontend(opencoreDir, true); // Run in background
  }, 1000);
  console.log('\n✓ Both servers started in background');
  console.log('Use "opencore stop" to stop them');
} else if (command === 'stop') {
  stopProcess('opencore-backend');
  stopProcess('opencore-frontend');
} else if (command === 'list') {
  listProcesses();
} else if (command === 'help' || command === '--help' || command === '-h') {
  console.log(`
OpenCore CLI - System Monitoring Platform

Usage:
  opencore <command> [options]

Commands:
  backend start    Start the backend server (background)
  backend stop     Stop the backend server
  frontend start   Start the frontend server (background)
  frontend stop    Stop the frontend server
  start            Start both backend and frontend (background)
  stop             Stop both backend and frontend
  list             List active OpenCore processes
  help             Show this help message

Examples:
  opencore backend start
  opencore frontend start
  opencore backend stop
  opencore frontend stop
  opencore start
  opencore stop
`);
} else {
  console.error(`Unknown command: ${command}`);
  console.error('Use: opencore [backend|frontend|start|stop|list|help]');
  process.exit(1);
}

