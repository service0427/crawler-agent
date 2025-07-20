const { GitHubMCPServer } = require('./github-server');
const { spawn } = require('child_process');
const path = require('path');

/**
 * MCP Integration for Crawler Agent
 * 
 * This module integrates Model Context Protocol (MCP) servers
 * into the crawler agent, providing enhanced capabilities for
 * interacting with external services like GitHub.
 */
class MCPIntegration {
  constructor() {
    this.servers = new Map();
    this.processes = new Map();
  }

  /**
   * Initialize MCP integration
   */
  async initialize() {
    console.log('Initializing MCP integration...');
    
    // GitHub 토큰 확인
    if (process.env.GITHUB_TOKEN) {
      console.log('GitHub token found, enabling GitHub MCP server');
      await this.startGitHubServer();
    } else {
      console.log('GITHUB_TOKEN not found, GitHub MCP server disabled');
    }
  }

  /**
   * Start GitHub MCP server as a subprocess
   */
  async startGitHubServer() {
    try {
      const serverPath = path.join(__dirname, 'github-server.js');
      
      // MCP 서버를 별도 프로세스로 실행
      const mcpProcess = spawn('node', [serverPath], {
        env: {
          ...process.env,
          GITHUB_TOKEN: process.env.GITHUB_TOKEN
        },
        stdio: ['pipe', 'pipe', 'pipe']
      });

      // 에러 처리
      mcpProcess.stderr.on('data', (data) => {
        const message = data.toString();
        if (message.includes('GitHub MCP Server started')) {
          console.log('✓ GitHub MCP server started successfully');
        } else {
          console.error('GitHub MCP server error:', message);
        }
      });

      mcpProcess.on('error', (error) => {
        console.error('Failed to start GitHub MCP server:', error);
      });

      mcpProcess.on('exit', (code) => {
        console.log(`GitHub MCP server exited with code ${code}`);
        this.processes.delete('github');
      });

      this.processes.set('github', mcpProcess);
      this.servers.set('github', {
        name: 'GitHub MCP Server',
        status: 'running',
        capabilities: [
          'search_repositories',
          'get_repository',
          'list_issues',
          'create_issue',
          'get_file_contents'
        ]
      });

    } catch (error) {
      console.error('Error starting GitHub MCP server:', error);
    }
  }

  /**
   * Execute MCP tool
   * @param {string} server - Server name (e.g., 'github')
   * @param {string} tool - Tool name
   * @param {object} args - Tool arguments
   */
  async executeTool(server, tool, args) {
    const mcpProcess = this.processes.get(server);
    
    if (!mcpProcess) {
      throw new Error(`MCP server '${server}' not running`);
    }

    return new Promise((resolve, reject) => {
      const request = {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: {
          name: tool,
          arguments: args
        },
        id: Date.now()
      };

      // Send request to MCP server
      mcpProcess.stdin.write(JSON.stringify(request) + '\n');

      // Handle response
      const responseHandler = (data) => {
        try {
          const response = JSON.parse(data.toString());
          if (response.id === request.id) {
            mcpProcess.stdout.removeListener('data', responseHandler);
            if (response.error) {
              reject(new Error(response.error.message));
            } else {
              resolve(response.result);
            }
          }
        } catch (error) {
          // Ignore parse errors for non-JSON output
        }
      };

      mcpProcess.stdout.on('data', responseHandler);

      // Timeout after 30 seconds
      setTimeout(() => {
        mcpProcess.stdout.removeListener('data', responseHandler);
        reject(new Error('MCP tool execution timeout'));
      }, 30000);
    });
  }

  /**
   * Get status of all MCP servers
   */
  getStatus() {
    const status = {};
    for (const [name, info] of this.servers.entries()) {
      status[name] = {
        ...info,
        running: this.processes.has(name)
      };
    }
    return status;
  }

  /**
   * Shutdown all MCP servers
   */
  async shutdown() {
    console.log('Shutting down MCP servers...');
    
    for (const [name, process] of this.processes.entries()) {
      console.log(`Stopping ${name} MCP server...`);
      process.kill('SIGTERM');
    }

    // Wait for processes to exit
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    this.processes.clear();
    this.servers.clear();
  }
}

// Export singleton instance
const mcpIntegration = new MCPIntegration();

module.exports = mcpIntegration;