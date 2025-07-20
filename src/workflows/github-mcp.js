const mcpIntegration = require('../mcp/mcp-integration');

/**
 * GitHub MCP Workflow
 * 
 * This workflow uses the MCP GitHub server to interact with GitHub
 */
module.exports = {
  name: 'github-mcp',
  description: 'Interact with GitHub using MCP',
  
  async run(params = {}) {
    const { action, ...args } = params;
    
    console.log(`[GitHub MCP] Executing action: ${action}`);
    
    try {
      let result;
      
      switch (action) {
        case 'search':
          result = await mcpIntegration.executeTool('github', 'search_repositories', {
            query: args.query || 'language:javascript',
            sort: args.sort || 'stars',
            order: args.order || 'desc',
            per_page: args.per_page || 10
          });
          break;
          
        case 'get-repo':
          if (!args.owner || !args.repo) {
            throw new Error('owner and repo parameters are required');
          }
          result = await mcpIntegration.executeTool('github', 'get_repository', {
            owner: args.owner,
            repo: args.repo
          });
          break;
          
        case 'list-issues':
          if (!args.owner || !args.repo) {
            throw new Error('owner and repo parameters are required');
          }
          result = await mcpIntegration.executeTool('github', 'list_issues', {
            owner: args.owner,
            repo: args.repo,
            state: args.state || 'open',
            labels: args.labels,
            per_page: args.per_page || 30
          });
          break;
          
        case 'create-issue':
          if (!args.owner || !args.repo || !args.title) {
            throw new Error('owner, repo, and title parameters are required');
          }
          result = await mcpIntegration.executeTool('github', 'create_issue', {
            owner: args.owner,
            repo: args.repo,
            title: args.title,
            body: args.body,
            labels: args.labels
          });
          break;
          
        case 'get-file':
          if (!args.owner || !args.repo || !args.path) {
            throw new Error('owner, repo, and path parameters are required');
          }
          result = await mcpIntegration.executeTool('github', 'get_file_contents', {
            owner: args.owner,
            repo: args.repo,
            path: args.path,
            ref: args.ref
          });
          break;
          
        default:
          throw new Error(`Unknown action: ${action}. Available actions: search, get-repo, list-issues, create-issue, get-file`);
      }
      
      // Parse result if it's text content
      if (result && result.content && result.content[0] && result.content[0].type === 'text') {
        try {
          const parsed = JSON.parse(result.content[0].text);
          return {
            success: true,
            data: parsed,
            timestamp: new Date().toISOString()
          };
        } catch (e) {
          // Return as is if not JSON
          return {
            success: true,
            data: result.content[0].text,
            timestamp: new Date().toISOString()
          };
        }
      }
      
      return {
        success: true,
        data: result,
        timestamp: new Date().toISOString()
      };
      
    } catch (error) {
      console.error('[GitHub MCP] Error:', error);
      return {
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }
};