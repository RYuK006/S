// gridlethal-server.js
// Standalone Node.js Dedicated Relay Server (Zero External Dependencies)
// Broadcasts binary snapshots between connected web clients using built-in http & crypto.

const http = require('http');
const crypto = require('crypto');

const PORT = process.env.PORT || 8080;
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('GRIDLETHAL Dedicated Netcode Relay Server Active\n');
});

const clients = new Set();

server.on('upgrade', (req, socket) => {
  if (req.headers['upgrade'] !== 'websocket') {
    socket.end('HTTP/1.1 400 Bad Request');
    return;
  }

  // WebSocket handshake
  const key = req.headers['sec-websocket-key'];
  const hash = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  const responseHeaders = [
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${hash}`
  ];
  socket.write(responseHeaders.join('\r\n') + '\r\n\r\n');

  clients.add(socket);
  console.log(`[NET] Client connected. Total active pilots: ${clients.size}`);

  socket.on('data', (buffer) => {
    // Relay raw frame to all other clients
    for (const client of clients) {
      if (client !== socket && client.writable) {
        client.write(buffer);
      }
    }
  });

  socket.on('close', () => {
    clients.delete(socket);
    console.log(`[NET] Client disconnected. Total active pilots: ${clients.size}`);
  });

  socket.on('error', () => {
    clients.delete(socket);
  });
});

server.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(`  GRIDLETHAL DEDICATED RELAY SERVER LISTENING ON :${PORT} `);
  console.log(`  Zero-dependency binary snapshot distribution active   `);
  console.log(`=======================================================`);
});
