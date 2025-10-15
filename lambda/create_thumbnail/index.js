exports.handler = (request, context, callback) => {
    console.log("Received request: " + JSON.stringify(request))

    return callback(null, {
        statusCode: 200,
        body: JSON.stringify({foo: "bar"}),
        headers: {
            "Content-Type": "application/json"
        }
    })
}