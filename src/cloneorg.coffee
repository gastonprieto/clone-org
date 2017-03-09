_ = require "lodash"
fp = require "lodash/fp"
Rx = require "rx"
Promise = require "bluebird"
PagesToStream = require "pages-to-stream"
GitHubClient = require "github"
inquirer = require "inquirer"
program = require "commander"
gitclone = Promise.promisify require "gitclone"
pathExists = require "path-exists"

getRepositories = _.curry (client, organization, lastResponse) ->
  $promise = if lastResponse? then client.getNextPage lastResponse else client.repos.getForOrg { org: organization }

  $promise.then (res) ->
    items: res.data
    nextToken: if client.hasNextPage res then res

readCredentials = ->
  inquirer.prompt [
    { name: "username", message: "Username?" }
    { name: "password", message: "Password?", type: "password" }
  ]

createClient = ({ username, password }) ->
  client = new GitHubClient
    debug: false
    protocol: "https"
    Promise: require "bluebird"

  client.authenticate {
    type: "basic"
    username
    password
  }

  client

cloneRepository = (organization, name) ->
  path = "#{organization}/#{name}"
  console.log "Cloning repository #{name} to #{path}..."
  gitclone path, { dest: path, ssh: true }

exist =  _.curry (organization, name) -> pathExists "#{organization}/#{name}"

program
  .usage "<organization>"
  .description "Clone all repositories of an organization"
  .parse process.argv

[ organization ] = program.args

return program.help() unless organization?

readCredentials()
.then (credentials) ->
  client = createClient credentials
  new PagesToStream getRepositories(client, organization)
  .stream()
  .map fp.property "name"
  .filter (name) -> exist(organization, name).then (exists) -> not exists
  .flatMapWithMaxConcurrent 1, (name) ->
    Rx.Observable.defer ->
      cloneRepository organization, name
  .toPromise()
.then -> console.log "done"
.catch console.log
