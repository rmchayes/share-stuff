const https = require("https");
const querystring = require("querystring");

exports.handler = async (event) => {
  const { code } = JSON.parse(event.body);
  // This is the Cognito Client ID
  const clientId = "xxx";
  // This is my website URL
  const redirectUri = "http://localhost:5173/";

  const postData = querystring.stringify({
    grant_type: "authorization_code",
    client_id: clientId,
    redirect_uri: redirectUri,
    code: code,
  });

  const options = {
    hostname: "xxx.auth.us-east-1.amazoncognito.com",
    port: 443,
    path: "/oauth2/token",
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        console.log("Received tokens from Cognito:", data);
        resolve({
          statusCode: 200,
          headers: {
            "Access-Control-Allow-Origin": "*", // Adjust as necessary for production
            "Content-Type": "application/json",
          },
          body: data,
        });
      });
    });

    req.on("error", (error) => {
      console.error("Error exchanging code for tokens:", error);
      reject({
        statusCode: 500,
        body: JSON.stringify({ message: "Error exchanging code for tokens" }),
      });
    });

    req.write(postData);
    req.end();
  });
};
