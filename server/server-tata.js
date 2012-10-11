var http            = require('http'),
    express         = require('express'),
    params          = require('express-params'),
    app             = express(),
    server          = http.createServer(app),
    port            = 8888,
    passport        = require('passport'),
    LocalStrategy   = require('passport-local').Strategy,
    flash           = require('connect-flash'),
    gm              = require('gm'),
    fs              = require('fs'),
    uploadDir       = __dirname + '/tmp/',
    collectionsDir  = __dirname + '/../public/img/collections/',
    thumbsDir       = __dirname + '/../public/img/thumbs/',
    log4js          = require('log4js');

log4js.configure({
    appenders: [
        { type: 'console', category: 'logFile'},
        {
            type: 'file',
            filename: './logs/server-tata.log4js.log',
            category: 'logFile',
            maxLogSize: 10*1024*1024*1024,
            backups: 5
        }
    ]
});

var logger = log4js.getLogger('logFile');
logger.setLevel('DEBUG');

var users = [
    {id:1,  username:'admin',   password:'password'},
    {id:2,  username:'user',    password:'password'}
];

function findById(id, fn) {
    var idx = id - 1;
    if (users[idx]) {
        fn(null, users[idx])
    } else {
        fn(new Error('User' + id + 'does not exists'));
    }
}

function findByUsername(username, fn) {
    for (var i=0; i<users.length; i++) {
        var user = users[i];
        if (user.username === username) {
            return fn(null, user);
        }
    }
    return fn(null, null);
}

passport.serializeUser(function(user, done) {
    done(null, user.id)
});

passport.deserializeUser(function(id, done) {
    findById(id, function (err, user){
        done(err, user);
    });
});

// Use the LocalStrategy within Passport.
//   Strategies in passport require a `verify` function, which accept
//   credentials (in this case, a username and password), and invoke a callback
//   with a user object.  In the real world, this would query a database;
//   however, in this example we are using a baked-in set of users.
passport.use(new LocalStrategy(
    function (username, password, done) {
        // asynchronous verification, for effect...
        process.nextTick(function () {

            // Find the user by username.  If there is no user with the given
            // username, or the password is not correct, set the user to `false` to
            // indicate failure and set a flash message.  Otherwise, return the
            // authenticated `user`.
            findByUsername(username, function (err, user) {
                if (err) {
                    return done(err);
                }
                if (!user) {
                    return done(null, false, { message:'Unknown user ' + username });
                }
                if (user.password != password) {
                    return done(null, false, { message:'Invalid password' });
                }
                return done(null, user);
            })
        });
    }
));

params.extend(app);
app.configure(function() {
    app.use(log4js.connectLogger(logger, { level: log4js.levels.DEBUG }));
    app.use(express.bodyParser({uploadDir: uploadDir}));
    app.use(express.cookieParser());
    app.use(express.session({secret: 'tata-server'}));
    app.use(express.methodOverride());
    app.use(flash());
    // Initialize Passport!  Also use passport.session() middleware, to support
    // persistent login sessions (recommended).
    app.use(passport.initialize());
    app.use(passport.session());
    app.use(app.router);
    app.use(express.static(__dirname + '/../public'));
});

app.get('/login', function(req, res){
    res.send({user: req.user, message: req.flash('error')});
});

// POST /login
//   Use passport.authenticate() as route middleware to authenticate the
//   request.  If authentication fails, the user will be redirected back to the
//   login page.  Otherwise, the primary route function function will be called,
//   which, in this example, will redirect the user to the home page.
//
//   curl -v -d "username=[username]&password=[password]" http://[ip]:[port]/login
app.post('/login', function(req, res, next) {
    passport.authenticate('local', function(err, user, info) {
        if (err) { return next(err) }
        if (!user) {
            return res.send(401);
        }
        req.logIn(user, function(err) {
            if (err) { return next(err); }
            return res.redirect('/');
        });
    })(req, res, next);
});


app.get('/logout', function(req, res){
    req.logout();
    res.redirect('/');
});

// Simple route middleware to ensure user is authenticated.
//   Use this route middleware on any resource that needs to be protected.  If
//   the request is authenticated (typically via a persistent login session),
//   the request will proceed.  Otherwise, the user will be redirected to the
//   login page.
function ensureAuthenticated(req, res, next) {
    if (req.isAuthenticated()) { return next(); }
    res.redirect('/login')
}

app.post('/upload', function (request, response, next) {
    if (!request.user) {
        logger.debug('There is no right to upload images');
        return;
    }
    logger.debug("Upload Request is called.");

    function makeThumbnail(file, thumbPath, thumbSide) {
        logger.debug('Thumbs full view image "%s"', file.name);
        gm(file.path).size(function (err, value) {
            if (err != null) {
                logger.debug(err.message);
                return;
            }
            logger.debug('Full view image "%s" dimensions: %d x %d', file.name, value.width, value.height);
            var width = value.width;
            var height = value.height;
            var sideMin = Math.min(width, height);
            var thumbQuality = 100;
            gm(file.path)
//                .crop(sideMin, sideMin, (width - sideMin) / 2, (height - sideMin) / 2)
                .thumb(thumbSide, thumbSide, thumbPath, thumbQuality, function (err) {
                    if (err != null) {
                        logger.debug(err.message);
                        return
                    }
                    logger.debug('Full view image "%s" was successfully thumbed', file.name);
                });
        });
    }

    function saveFile(file, collectionName) {
        if (fs.existsSync(file.path)) {
            fs.readFile(file.path, function (err, data) {
                var fullViewDir = collectionsDir + collectionName + '/';
                var thumbViewDir = thumbsDir + collectionName + '/';
                var fullViewPath = fullViewDir + file.name;
                var thumbViewPath = thumbViewDir + file.name;
                var thumbSide = 400;

                if (!fs.existsSync(fullViewDir)) {
                    fs.mkdirSync(fullViewDir);
                }
                if (!fs.existsSync(thumbViewDir)) {
                    fs.mkdirSync(thumbViewDir);
                }
                logger.debug('Creating full view image "%s" for collection "%s"', file.name, collectionName);
                fs.writeFile(fullViewPath, data, function (err) {
                    if (err != null) {
                        logger.debug(err.message);
                        return;
                    }
                    logger.debug('Full view image "%s" was successfully created', file.name);
                    makeThumbnail(file, thumbViewPath, thumbSide);
                });
            });
        }

    }

    var nameField = request.param('name');
    var today = new Date();
    var collectionName = nameField != undefined && nameField != null && nameField.length
        ? nameField
        : "collection-" + (today.toDateString() + " " + today.toTimeString().slice(0, 8)).replace(/[ ]/g, "-");

    if (Array.isArray(request.files.upload)){
        request.files.upload.forEach(function (file) {
            saveFile(file, collectionName);
        });
    } else {
        saveFile(request.files.upload, collectionName);
    }

    logger.debug('Upload request was successfully parsed');
    response.end();
});


app.get('/struct', function (request, response, next) {
    logger.debug('Get collections list request');
    var collectionsFolders = fs.readdirSync(collectionsDir);
    var result = {};
    for (var i = 0; i < collectionsFolders.length; i++) {
        var collection = collectionsFolders[i];
        result[collection] = fs.readdirSync(collectionsDir + collection);
    }
    response.send(result);
});

app.get('/remove/:collectionName/:fileName', function (request, response, next) {
    if (!request.user) {
        logger.debug("There are no rights to remove image!")
        return;
    }
    var collectionName = request.params.collectionName;
    var fileName = request.params.fileName;
    if ((collectionName + '').length === 0 || (fileName + '').length === 0) return;
    logger.debug('Get request to remove image "%s" from collection "%s"', fileName, collectionName);
    if (fs.existsSync(collectionsDir + collectionName + '/' + fileName))
        fs.unlink(collectionsDir + collectionName + '/' + fileName, function (err) {
            if (err != null) {
                logger.debug(err.message);
                return;
            }
            logger.debug('Image "%s" was successfully removed from collection "%s"', fileName, collectionName);
        });
    if (fs.existsSync(thumbsDir + collectionName + '/' + fileName))
        fs.unlink(thumbsDir + collectionName + '/' + fileName, function (err) {
            if (err != null) {
                logger.debug(err.message);
                return;
            }
            logger.debug('Thumb "%s" was successfully removed from collection "%s"', fileName, collectionName);
        });
});

server.listen(port);
