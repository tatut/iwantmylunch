//
//  main.swift
//  iwantmylunch
// 
//  Simple command line utility to fetch the account balance from your edenred lunch card.
// 
//  Compile with swiftc and run with 2 parameters: your user name and password for edenred service
//
//  Created by Tatu Tarvainen on 8.4.2016.
//  Copyright © 2016 Tatu Tarvainen. All rights reserved.
//

import Foundation

let baseURL = "https://www.myedenred.fi/API/WebServices/"
let loginURL = baseURL+"UserAccount.svc/UserLogin3"
let balanceURL = baseURL+"UserAccount.svc/GetAccountBalance"

extension NSData {
    func parseJSON() -> NSDictionary? {
        let jsonResult: NSDictionary? = try? NSJSONSerialization.JSONObjectWithData(self, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
        return jsonResult

    }
}

func post(req : NSURLRequest, success: (NSData -> ())) {
    let semaphore = dispatch_semaphore_create(0)
    let session = NSURLSession.sharedSession()
    let task = session.dataTaskWithRequest(req) {
        data, response, error in
        if let err = error {
            print("Error in request: \(err)")
        } else {
            if let d = data {
                success(d)
            } else {
                print("No error, but NSData is nil!")
            }
        }
        dispatch_semaphore_signal(semaphore)
    }
    task.resume()
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
}

func jsonReq(url:String, body:AnyObject) -> NSURLRequest {
    let req = NSMutableURLRequest(URL: NSURL(string: url)!)
    req.HTTPMethod = "POST"
    req.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(body, options: NSJSONWritingOptions(rawValue:0))
    req.HTTPShouldHandleCookies = true
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    req.addValue("https://www.myedenred.fi/", forHTTPHeaderField: "Referer")
    return req
}

func login(user:String, password:String) -> String? {
    let cred = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)
    let base64Encoded = cred!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    let req = jsonReq(loginURL, body: ["credentials": base64Encoded, "hashed": false])
    
    var token : String?
    post(req) {
        data in
        if let parsedToken = data.parseJSON()?["UserLogin3Result"]?["UserSessionToken"] as? String {
            token = parsedToken
        } else {
            print("No user session token, invalid login?")
        }
    }
    
    return token
}

func balance(token: String) -> String? {
    let req = jsonReq(balanceURL, body: ["userSessionToken": token, "serviceTypeCode": "TD", "walletTypeCode": "TR"])
    var balance : String?
    post(req) {
        data in
        if let amount = data.parseJSON()?["GetAccountBalanceResult"]?["BalanceField"]??["AmountField"] as? String {
            let money = Int(amount)!
            let euros = money/100
            let cents = money - euros*100
            balance = String(format: "%d,%02d€", euros, cents)
        }
    }
    return balance
}

if Process.argc < 3 {
    print("Usage: \(Process.arguments[0]) <user> <password>")
} else {
    let user = Process.arguments[1]
    let password = Process.arguments[2]
    if let token = login(user, password: password) {
        if let b = balance(token) {
            print(b)
        }
    }
}