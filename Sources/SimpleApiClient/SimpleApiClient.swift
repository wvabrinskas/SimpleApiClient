//
//  API.swift
//  SwiftChat
//
//  Created by William Vabrinskas on 2/14/20.
//  Copyright © 2020 William Vabrinskas. All rights reserved.
//

import Foundation

public enum RequestType: String {
    case GET
    case POST
}

protocol SimpleApiClient {
    associatedtype TModel: Decodable
    static func request(data: Data?, urlString: String, type: RequestType) -> URLRequest?
    func post(endpoint: String, data: Data?, completion: @escaping(_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?) -> ())
    func get(endpoint: String, completion: @escaping(_ result: Result<TModel?, Error>?) -> ())
    func decode(data: Data?) throws -> TModel?
}

extension SimpleApiClient {
    static func request(data: Data? = nil, urlString: String, type: RequestType) -> URLRequest? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpBody = data
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = type.rawValue
        
        return request
    }
    
    public func decode(data: Data?) throws -> TModel? {
        if let data = data {
            do {
                let obj = try JSONDecoder().decode(TModel.self, from: data)
                return obj
            } catch {
                print(error.localizedDescription)
            }
        }
        
        return nil
    }
    
    public func post(endpoint: String, data: Data? = nil, completion: @escaping(_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?) -> ()) {
        guard let request = Self.request(data: data, urlString: endpoint, type: .POST) else {
            completion(nil, nil, nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (dataResp, response, error) in
            completion(dataResp, response, error)
        }.resume()
    }
    
    public func get(endpoint: String, completion: @escaping(_ result: Result<TModel?, Error>?) -> ()) {
        guard let request = Self.request(urlString: endpoint, type: .GET) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (dataResp, response, error) in
            guard error == nil else {
                completion(nil)
                return
            }
            let result: Result<TModel?, Error> = Result { try self.decode(data: dataResp) }
            completion(result)
        }.resume()
    }
}
