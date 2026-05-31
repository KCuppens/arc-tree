'use strict'

const path = require('path')

const SRC = __dirname

module.exports = {
  serverDir:    path.join(SRC, 'server'),
  serverRoutes: [path.join(SRC, 'server', 'tree.arc')],
  widgetsDir:   path.join(SRC, 'widgets'),
  version:      require('../package.json').version,
}
