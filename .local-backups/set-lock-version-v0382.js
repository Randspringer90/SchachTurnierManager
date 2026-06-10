const fs = require('fs');
const path = process.argv[1];
const version = process.argv[2];
const lock = JSON.parse(fs.readFileSync(path, 'utf8'));
lock.version = version;
if (lock.packages && lock.packages['']) {
  lock.packages[''].version = version;
}
fs.writeFileSync(path, JSON.stringify(lock, null, 2) + '\n', 'utf8');