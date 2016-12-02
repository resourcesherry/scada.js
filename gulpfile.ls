argv = require 'yargs' .argv

project = argv.project
project = \aktos if not project
console.log "------------------------------------------"
console.log "Compiling for project: #{project}"
console.log "------------------------------------------"

require! <[ watchify gulp browserify glob path fs globby run-sequence ]>
require! 'prelude-ls': {union, join, keys}
require! 'vinyl-source-stream': source
require! 'vinyl-buffer': buffer
require! 'gulp-watch': watch
require! 'gulp-jade': jade
require! 'node-notifier': notifier
require! 'gulp-concat': cat
require! 'gulp-uglify': uglify
require! './src/lib/aea': {sleep}
require! 'gulp-flatten': flatten
require! 'gulp-tap': tap
require! 'gulp-cached': cache
require! 'gulp-sourcemaps': sourcemaps
require! 'browserify-livescript'
require! './preparse': {preparseRactive}


# Build Settings
notification-enabled = yes

# Project Folder Structure

paths = {}
paths.vendor-folder = "#{__dirname}/vendor"
paths.build-folder = "#{__dirname}/build"

paths.client-public = "#{paths.build-folder}/public"
paths.client-src = "#{__dirname}/src/client"
paths.client-apps = "#{paths.client-public}"
paths.client-webapps = "#{__dirname}/apps/#{project}/webapps"

paths.lib-src = "#{__dirname}/src/lib"

paths.components-src = "#{paths.client-src}/components"


console.log "Paths: "
for p, k of paths
    console.log "PATH for #{p} is: #{k}"
console.log "---------------------------"

notifier.notify {title: "aktos-scada2" message: "Project #{project} started!"}

on-error = (source, err) ->
    msg = "GULP ERROR: #{source} :: #{err?.to-string!}"
    notifier.notify {title: "GULP.#{source}", message: msg} if notification-enabled
    console.log msg

log-info = (source, msg) ->
    console-msg = "GULP INFO: #{source} : #{msg}"
    notifier.notify {title: "GULP.#{source}", message: msg} if notification-enabled
    console.log console-msg

is-module-index = (base, file) ->
    if base is path.dirname file
        #console.log "this is a simple file: ", file
        return true

    [filename, ext] = path.basename file .split '.'

    if filename is "#{path.basename path.dirname file}"
        #console.log "this is custom module: ", file
        return true

    if file is "#{path.dirname file}/index.#{ext}"
        #console.log "this is a standart module", file
        return true

    #console.log "not a module index: #{file} (filename: #{filename}, ext: #{ext})"
    return false


only-compile = yes if argv.compile is true

# Organize Tasks
gulp.task \default, ->
    if argv.clean is true
        console.log "Clearing build directory..."

        deleteFolderRecursive = (path) ->
            if fs.existsSync(path)
                fs.readdirSync(path).forEach (file,index) ->
                    curPath = path + "/" + file
                    if(fs.lstatSync(curPath).isDirectory())  # recurse
                      deleteFolderRecursive(curPath)
                    else
                        # delete file
                        fs.unlinkSync(curPath)
                fs.rmdirSync(path)
        deleteFolderRecursive paths.build-folder
        return

    do function run-all
        gulp.start <[ browserify html vendor vendor-css assets jade ]>

    if only-compile
        console.log "Gulp will compile only once..."
        return


    for-jade =
        "#{paths.client-src}/components/**/*.jade"
        "!#{paths.client-src}/components/components.jade"

        "#{paths.client-webapps}/**/*.jade"
        "#{paths.client-src}/templates/**/*.jade"

    watch for-jade, ->
        gulp.start \jade

    watch "#{paths.vendor-folder}/**", (event) ->
        gulp.start <[ vendor vendor-css ]>


    for-components =
        "#{paths.client-src}/components/**/*.ls"
        "!#{paths.client-src}/components/components.ls"

    watch for-components, ->
        gulp.start \generate-components-module


# Copy js and html files as is
gulp.task \copy-js, ->
    gulp.src "#{paths.client-src}/**/*.js", {base: paths.client-src}
        .pipe gulp.dest paths.client-apps

gulp.task \html, ->
    base = "#{paths.client-webapps}"
    gulp.src "#{base}/**/*.html", {base: base}
        .pipe gulp.dest "#{paths.client-public}"


gulp.task \generate-components-module ->
    console.log "RUNNING GENERATE_COMPONENTS_MODULE"
    components = glob.sync "#{paths.components-src}/**/*.ls"
    components = [.. for components when is-module-index paths.components-src, ..]
    index = "#{paths.components-src}/components.ls"
    components = [.. for components when .. isnt index]
    components = [path.basename path.dirname .. for components]

    fs.write-file-sync index, '' # delete the file
    fs.append-file-sync index, '# Do not edit this file manually! \n'
    fs.append-file-sync index, join "" ["require! './#{..}'\n" for components]
    fs.append-file-sync index, "module.exports = { #{join ', ', components} }\n"



gulp.task \browserify, run-sequence \copy-js, \generate-components-module, !->
    bundler = browserify do
        entries:
            "#{__dirname}/apps/demeter/webapps/demeter/demeter.ls"
            ...
        debug: true
        paths:
            paths.components-src
            paths.lib-src
            paths.client-webapps
        extensions: <[ .ls ]>
        cache: {}
        package-cache: {}
        plugin: [watchify unless only-compile]

    bundler.transform \browserify-livescript

    do function bundle
        bundler
            .bundle!
            .on \error, (err) ->
                on-error \browserify, err
                console.log "err stack: ", err.stack
                @emit \end
            .pipe source \public/demeter.js
            .pipe buffer!
            .pipe sourcemaps.init {+load-maps, +large-file}
            .pipe sourcemaps.write './'
            .pipe gulp.dest './build'
            .pipe tap (file) ->
                log-info \browserify, "Browserify finished"

    unless only-compile
        bundler.on \update, bundle

# Concatenate vendor javascript files into public/js/vendor.js
gulp.task \vendor, ->
    files = glob.sync "./vendor/**/*.js"
    gulp.src files
        .pipe tap (file) ->
            #console.log "VENDOR: ", file.path
        .pipe cat "vendor.js"
        .pipe gulp.dest "#{paths.client-apps}/js"

# Concatenate vendor css files into public/css/vendor.css
gulp.task \vendor-css, ->
    gulp.src "#{paths.vendor-folder}/**/*.css"
        .pipe cat "vendor.css"
        .pipe gulp.dest "#{paths.client-apps}/css"

# Copy assets into the public directory as is
gulp.task \assets, ->
    gulp.src "#{paths.client-src}/assets/**/*", {base: "#{paths.client-src}/assets"}
        .pipe gulp.dest paths.client-public

# Compile Jade files in paths.client-src to the paths.client-tmp folder
gulp.task \jade, -> run-sequence \browserify, \jade-components, ->
    base = "#{paths.client-webapps}"
    files = glob.sync "#{base}/**/*.jade"
    files = [.. for files when is-module-index base, ..]
    gulp.src files
        .pipe tap (file) ->
            console.log "JADE: compiling file: ", path.basename file.path
        .pipe jade {pretty: yes}
        .on \error, (err) ->
            on-error \jade, err
            @emit \end
        .pipe flatten!
        .pipe gulp.dest paths.client-apps
        .pipe tap (file) ->
            log-info \jade, "Jade finished"
            preparseRactive!
            console.log "preparsing finished..."



gulp.task \jade-components ->
    # create a file which includes all jade file includes in it
    console.log "STARTED JADE_COMPONENTS"

    base = paths.components-src
    main = "#{base}/components.jade"

    components = globby.sync ["#{base}/**/*.jade", "!#{base}/components.jade"]
    components = [path.relative base, .. for components]

    for i in components
        console.log "jade-component: ", i


    # delete the main file
    fs.write-file-sync main, '// Do not edit this file manually! \n'

    for comp in components
        fs.append-file-sync main, "include #{comp}\n"
