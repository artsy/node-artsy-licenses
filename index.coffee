_ = require 'underscore'
csv = require 'csv'
fs = require 'fs'
async = require 'async'
path = require 'path'
nlf = require 'nlf'
{ exec } = require 'child_process'
url = require 'url'

repos = [
  'inquiry-map',
  'refraction',
  'halbone',
  '3d-artsy',
  'backbone-cache-sync',
  'artsy-2013',
  'torque',
  'positron',
  'europa',
  'microgravity',
  'artsy-wwwify',
  'flare',
  'monolith',
  'force',
  'irtsybot',
  '2014.artsy.net',
  'inertia'
]
missingLicenses = []

cloneAndInstallRepos = (callback) ->
  async.map repos, (repo, cb) ->
    cmd = [
      "git clone git@github.com:artsy/#{repo}.git clones/#{repo}"
      "cd clones/#{repo}"
      "rm -rf node_modules"
    ].join(' && ')
    cmd += [
      "rm npm-shrinkwrap.json"
      "npm install"
    ].join('; ')
    exec cmd, (err, stdout, stderr) ->
      console.log(err, stdout, cmd)
      cb()
  , (err) ->
    console.log "DONE cloning!"
    callback()

writeCSVs = (callback) ->
  async.mapSeries repos, (repo, cb) ->
    console.log "Exporting #{repo}..."
    repoToCSV repo, (err, data) ->
      fs.writeFile "#{__dirname}/csvs/#{repo}.csv", data, cb
  , ->
    console.log 'DONE!'
    # console.log 'Missing licenses for...'
    # console.log "#{pkg.name} #{pkg.url}" for pkg in missingLicenses
    callback()

repoToCSV = (repo, callback) ->
  nlf.find {
    directory: __dirname + '/clones/' + repo,
  }, (err, data) ->
    return callback err if err
    pkgs = {}
    # Map into  { packageName: { name: version:, homepage:, summary:, license } }
    for pkg in data
      pkgs[pkg.name] ?= {}
      pkgs[pkg.name].name or= pkg.name
      pkgs[pkg.name].version or= pkg.version
      pkgs[pkg.name].homepage or= pkg.repository
      pkgs[pkg.name].license or= getLicense(pkg)
    # Map into CSV data
    csvData = [['name', 'version', 'homepage', 'summary', 'license']]
    csvData = csvData.concat (for n, pkgData of pkgs when pkgData.license or pkgData.homepage
      { name, version, homepage, license } = pkgData
      [name, version, homepage, '', license]
    )
    # Find pkgs with missing licenses
    for n, pkgData of pkgs when not pkgData.license
      console.log "Missing license for #{pkgData.name} at #{pkgData.homepage} in #{repo}"
      missingLicenses.push { name: pkgData.name, url: pkgData.homepage }
    csv.stringify csvData, callback

getLicense = (pkg) ->
  # package.json
  license = _.compact(_.pluck(pkg.licenseSources.package.sources, 'license'))[0]
  # LISCENCE file
  license or= pkg.licenseSources.license.sources[0]?.name?()
  license or= 'MIT' if pkg.licenseSources.license.sources[0]?.text?.match /MIT/i
  license or= 'Apache 2.0' if pkg.licenseSources.license.sources[0]?.text?.match /Apache.*2/i
  # README file
  license or= pkg.licenseSources.readme.sources[0]?.name?()
  license or= 'MIT' if pkg.licenseSources.readme.sources[0]?.text?.match /MIT/i
  license or= 'Apache 2.0' if pkg.licenseSources.readme.sources[0]?.text?.match /Apache.*2/i
  # Default to MIT for any Artsy repos
  license or= 'MIT' if pkg.repository.match(/artsy|craigspaeth|mikherman/i) or pkg.name.match(/artsy/i)
  # Give up
  license or= ''
  # Normalize common license names
  license = 'MIT' if license.match /MIT/i
  license = 'Apache 2.0' if license.match /Apache.*2/i
  license = 'BSD' if license.match /BSD/i
  license

switch process.argv[2]
  when 'clone' then cloneAndInstallRepos process.exit
  when 'csvs' then writeCSVs process.exit
