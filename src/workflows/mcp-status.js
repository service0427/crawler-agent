const mcpIntegration = require('../mcp/mcp-integration');

/**
 * MCP Status Workflow
 * 
 * Returns the status of all MCP servers
 */
module.exports = {
  name: 'mcp-status',
  description: 'Get status of MCP servers',
  
  async run(params = {}) {
    console.log('[MCP Status] Checking MCP server status...');
    
    try {
      const status = mcpIntegration.getStatus();
      
      return {
        success: true,
        data: {
          servers: status,
          count: Object.keys(status).length
        },
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('[MCP Status] Error:', error);
      return {
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }
};