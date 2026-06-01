'use strict'
const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const pkg = require('../src/index.js')

test('index.js — exports all required fields with truthy values', () => {
  const required = ['serverDir', 'serverRoutes', 'widgetsDir', 'version']
  for (const key of required) {
    assert.ok(key in pkg,  `export missing: ${key}`)
    assert.ok(pkg[key],    `export is falsy: ${key}`)
  }
})

test('index.js — serverRoutes is a non-empty array', () => {
  assert.ok(Array.isArray(pkg.serverRoutes), 'serverRoutes should be an array')
  assert.ok(pkg.serverRoutes.length > 0,     'serverRoutes should not be empty')
})

test('index.js — exported directory paths exist on disk', () => {
  assert.ok(fs.existsSync(pkg.serverDir),  `serverDir not found: ${pkg.serverDir}`)
  assert.ok(fs.existsSync(pkg.widgetsDir), `widgetsDir not found: ${pkg.widgetsDir}`)
})

test('index.js — all serverRoutes files exist on disk', () => {
  for (const route of pkg.serverRoutes) {
    assert.ok(fs.existsSync(route), `serverRoute not found: ${route}`)
  }
})

test('index.js — version matches package.json', () => {
  const pkgJson = require('../package.json')
  assert.equal(pkg.version, pkgJson.version)
})
