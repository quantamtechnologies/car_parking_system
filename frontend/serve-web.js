const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, 'build/web');
const rootLower = root.toLowerCase();
const port = Number(process.env.PORT || 8080);
const host = process.env.HOST || '127.0.0.1';

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
  '.bin': 'application/octet-stream',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
};

http
  .createServer((req, res) => {
    let requestPath = decodeURIComponent((req.url || '/').split('?')[0]);

    if (requestPath === '/') {
      requestPath = '/index.html';
    }
    if (requestPath.startsWith('/')) {
      requestPath = requestPath.slice(1);
    }

    const filePath = path.resolve(root, requestPath);
    if (!filePath.toLowerCase().startsWith(rootLower)) {
      res.writeHead(403);
      res.end('Forbidden');
      return;
    }

    fs.readFile(filePath, (error, data) => {
      if (error) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }

      res.writeHead(200, {
        'Content-Type': mime[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
        'Cache-Control': 'no-store',
      });
      res.end(data);
    });
  })
  .listen(port, host, () => {
    console.log(`Serving http://${host}:${port}/`);
    console.log(`Root: ${root}`);
  });
