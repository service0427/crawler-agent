const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { Octokit } = require('@octokit/rest');
const { z } = require('zod');

// GitHub API 클라이언트 설정
let octokit;

// 도구 정의
const tools = {
  search_repositories: {
    name: 'search_repositories',
    description: 'Search for GitHub repositories',
    inputSchema: z.object({
      query: z.string().describe('Search query'),
      sort: z.enum(['stars', 'forks', 'help-wanted-issues', 'updated']).optional(),
      order: z.enum(['asc', 'desc']).optional(),
      per_page: z.number().min(1).max(100).optional().default(30)
    })
  },
  get_repository: {
    name: 'get_repository',
    description: 'Get information about a specific repository',
    inputSchema: z.object({
      owner: z.string().describe('Repository owner'),
      repo: z.string().describe('Repository name')
    })
  },
  list_issues: {
    name: 'list_issues',
    description: 'List issues in a repository',
    inputSchema: z.object({
      owner: z.string().describe('Repository owner'),
      repo: z.string().describe('Repository name'),
      state: z.enum(['open', 'closed', 'all']).optional().default('open'),
      labels: z.string().optional().describe('Comma-separated list of labels'),
      per_page: z.number().min(1).max(100).optional().default(30)
    })
  },
  create_issue: {
    name: 'create_issue',
    description: 'Create a new issue in a repository',
    inputSchema: z.object({
      owner: z.string().describe('Repository owner'),
      repo: z.string().describe('Repository name'),
      title: z.string().describe('Issue title'),
      body: z.string().optional().describe('Issue body'),
      labels: z.array(z.string()).optional().describe('Labels to assign')
    })
  },
  get_file_contents: {
    name: 'get_file_contents',
    description: 'Get contents of a file from a repository',
    inputSchema: z.object({
      owner: z.string().describe('Repository owner'),
      repo: z.string().describe('Repository name'),
      path: z.string().describe('File path'),
      ref: z.string().optional().describe('Branch/tag/commit ref')
    })
  }
};

// MCP 서버 생성
class GitHubMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'github-mcp-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  setupHandlers() {
    // 도구 목록 요청 처리
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: Object.values(tools).map(tool => ({
        name: tool.name,
        description: tool.description,
        inputSchema: tool.inputSchema
      }))
    }));

    // 도구 실행 요청 처리
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      if (!octokit) {
        throw new Error('GitHub client not initialized. Please set GITHUB_TOKEN environment variable.');
      }

      try {
        switch (name) {
          case 'search_repositories':
            return await this.searchRepositories(args);
          
          case 'get_repository':
            return await this.getRepository(args);
          
          case 'list_issues':
            return await this.listIssues(args);
          
          case 'create_issue':
            return await this.createIssue(args);
          
          case 'get_file_contents':
            return await this.getFileContents(args);
          
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`
            }
          ]
        };
      }
    });
  }

  async searchRepositories(args) {
    const result = await octokit.search.repos({
      q: args.query,
      sort: args.sort,
      order: args.order,
      per_page: args.per_page
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            total_count: result.data.total_count,
            repositories: result.data.items.map(repo => ({
              full_name: repo.full_name,
              description: repo.description,
              stars: repo.stargazers_count,
              language: repo.language,
              url: repo.html_url
            }))
          }, null, 2)
        }
      ]
    };
  }

  async getRepository(args) {
    const result = await octokit.repos.get({
      owner: args.owner,
      repo: args.repo
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            name: result.data.name,
            full_name: result.data.full_name,
            description: result.data.description,
            stars: result.data.stargazers_count,
            forks: result.data.forks_count,
            language: result.data.language,
            created_at: result.data.created_at,
            updated_at: result.data.updated_at,
            url: result.data.html_url
          }, null, 2)
        }
      ]
    };
  }

  async listIssues(args) {
    const params = {
      owner: args.owner,
      repo: args.repo,
      state: args.state,
      per_page: args.per_page
    };

    if (args.labels) {
      params.labels = args.labels;
    }

    const result = await octokit.issues.listForRepo(params);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            count: result.data.length,
            issues: result.data.map(issue => ({
              number: issue.number,
              title: issue.title,
              state: issue.state,
              created_at: issue.created_at,
              user: issue.user.login,
              labels: issue.labels.map(l => l.name),
              url: issue.html_url
            }))
          }, null, 2)
        }
      ]
    };
  }

  async createIssue(args) {
    const result = await octokit.issues.create({
      owner: args.owner,
      repo: args.repo,
      title: args.title,
      body: args.body,
      labels: args.labels
    });

    return {
      content: [
        {
          type: 'text',
          text: `Issue created successfully: #${result.data.number} - ${result.data.title}\nURL: ${result.data.html_url}`
        }
      ]
    };
  }

  async getFileContents(args) {
    try {
      const result = await octokit.repos.getContent({
        owner: args.owner,
        repo: args.repo,
        path: args.path,
        ref: args.ref
      });

      if (result.data.type === 'file') {
        const content = Buffer.from(result.data.content, 'base64').toString('utf-8');
        return {
          content: [
            {
              type: 'text',
              text: content
            }
          ]
        };
      } else {
        return {
          content: [
            {
              type: 'text',
              text: `Path ${args.path} is a directory, not a file.`
            }
          ]
        };
      }
    } catch (error) {
      if (error.status === 404) {
        return {
          content: [
            {
              type: 'text',
              text: `File not found: ${args.path}`
            }
          ]
        };
      }
      throw error;
    }
  }

  async start() {
    // GitHub 토큰 확인
    const token = process.env.GITHUB_TOKEN;
    if (!token) {
      console.error('GITHUB_TOKEN environment variable is required');
      process.exit(1);
    }

    // Octokit 초기화
    octokit = new Octokit({
      auth: token
    });

    // 서버 시작
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('GitHub MCP Server started');
  }
}

// 서버 실행
if (require.main === module) {
  const server = new GitHubMCPServer();
  server.start().catch(console.error);
}

module.exports = { GitHubMCPServer };