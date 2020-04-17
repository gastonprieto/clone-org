_ = require "lodash"
fp = require "lodash/fp"
Promise = require "bluebird"
highland = require "highland"
HighlandPagination = require "highland-pagination"
{ Octokit } = require "@octokit/rest"
{ createBasicAuth } = require "@octokit/auth-basic"
inquirer = require "inquirer"
program = require "commander"
gitclone = Promise.promisify require "git-clone"
pathExists = require "path-exists"

require "highland-concurrent-flatmap"

getRepositories = (client, organization) -> 
  Promise.resolve client.repos.listForOrg({
    org: organization
  })

readCredentials = ->
  inquirer.prompt [
    { name: "username", message: "Username?" }
    { name: "password", message: "Password?", type: "password" }
  ]

createClient = ({ username, password }) ->
  auth = createBasicAuth {
    username
    password
    on2Fa: => inquirer.prompt "Two-factor authentication Code:"
  }

  Promise.resolve auth({ type: "token" })
  .then ({ token }) -> new Octokit { auth: token  }

cloneRepository = ({ ssh_url, full_name }) ->
  console.log "Cloning repository #{full_name}..."
  gitclone ssh_url, full_name, {}
  .tap console.log

exist =  _.curry (full_name) -> pathExists full_name

program
  .usage "<organization>"
  .description "Clone all repositories of an organization"
  .parse process.argv

[ organization ] = program.args

return program.help() unless organization?

readCredentials()
.then (credentials) -> createClient credentials
.then (client) ->
  highland getRepositories(client, organization)
  .merge()
  .filter ({ full_name }) -> exist(full_name).then (exists) -> not exists
  .concurrentFlatMap 10, (repo) -> highland cloneRepository repo
  .reduce 0, (accum) -> accum + 1
  .toPromise Promise
.then (amountImported) -> console.log "done, imported #{ amountImported } repositories"
.catch (err) -> console.error "An error has ocurred", err
