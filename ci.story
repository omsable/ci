###
Build with Storyscript on Asyncy
  Learn more at https://asyncy.com
###

when http server listen path:'/' method:'POST' as req
    # First validate the webhook is from GitHub
    if github validate signature:req.headers['X-Hub-Signature'] data:req.body_raw == false
        req set_status code:400
        req write content:'GitHub signature not valid'
        return

    # Check if the event is a new installation
    event = req.headers['X-GitHub-Event']
    if event == 'installation'
        if req.body['action'] == 'created'
            redis hset hash:'apps' key:req.body['installation']['account']['id']
                       value:req.body['installation']['id']
            req write content:'Application created acknowledged.'
        else
            redis hdel hash:'apps' key:req.body['installation']['account']['id']
            req write content:'Application deleted acknowledged.'
        return

    # Create some reusable variables
    installation = redis hget hash:'apps' key:req.body['repository']['owner']['id']
    token = github getInstallAccessToken :installation
    repo = req.body['repository']['full_name']
    context = 'ci/microservice.guide'

    # Set github pending
    github status :repo :token :context state:'pending'
                  description:'Validating the microservice.yml'

    # Get the yaml contents
    omgyml = github contents :repo :token path:'microservice.yml'

    # Validate the yaml against the omg microservice
    res = omg validate yaml:omgyml
    if res.valid
        redis hset hash:'badges' key:repo value:'pass'
        github status :repo :token :context state:'success'
                      description:'microservice.yml is valid.'
    else
        redis hset hash:'badges' key:repo value:'fail'
        # TODO add github checks here for the list of line errors
        github status :repo :token :context state:'failure'
                      description:res.reason


when http server listen path:'/<slug>' method:'GET' as req
    res = redis hget hash:'badges' key:req.path_params['slug']
    if res == 'pass'
        req redirect url:'https://img.shields.io/badge/OMG-valid-brightgreen.svg'
    else if res == 'fail'
        req redirect url:'https://img.shields.io/badge/OMG-invalid-red.svg'
    else
        req redirect url:'https://img.shields.io/badge/OMG-unknown-lightgrey.svg'
