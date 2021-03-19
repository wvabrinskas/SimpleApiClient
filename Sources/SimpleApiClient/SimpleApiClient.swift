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

public enum HTTPError: Error {
  case loadError
  
  var localizedDescription: String {
    switch self {
    case .loadError:
      return "could not load data from response"
    }
  }
}

public protocol SimpleApiClient {
  static var authorizationHeaders: [String: String]? { get set }
  static func request(data: Data?, urlString: String, type: RequestType) -> URLRequest?
  func post(endpoint: String,
            headers: [String: String],
            data: Data?,
            completion: @escaping(_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?) -> ())
  func postFormEncoded(endpoint: String,
                       headers: [String: String],
                       data: Data?,
                       completion: @escaping(_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?) -> ())
  func get<TModel: Decodable>(endpoint: String,
                              headers: [String: String],
                              data: Data?,
                              completion: @escaping(Result<TModel?, Error>?) -> ())
  func decode<TModel: Decodable>(data: Data?) throws -> TModel?
}

public extension SimpleApiClient {
  
  static var authorizationHeaders: [String: String]? {
    return nil
  }
  
  static func requestForm(data: Data? = nil, urlString: String, type: RequestType) -> URLRequest? {
    guard let url = URL(string: urlString) else {
      return nil
    }
    
    var request = URLRequest(url: url)
    request.httpBody = data
    request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")

    if let auth = authorizationHeaders {
      auth.forEach { (key, value) in
        request.addValue(value, forHTTPHeaderField: key)
      }
    }
    request.httpMethod = type.rawValue
    
    return request
  }
  
  static func request(data: Data? = nil, urlString: String, type: RequestType) -> URLRequest? {
    guard let url = URL(string: urlString) else {
      return nil
    }
    
    var request = URLRequest(url: url)
    request.httpBody = data
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    
    if let auth = authorizationHeaders {
      auth.forEach { (key, value) in
        request.addValue(value, forHTTPHeaderField: key)
      }
    }
    request.httpMethod = type.rawValue
    
    return request
  }
  
  func decode<TModel: Decodable>(data: Data?) throws -> TModel? {
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
  
  func postFormEncoded(endpoint: String,
                       headers: [String: String] = [:],
                       data: Data? = nil,
                       completion: @escaping(_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?) -> ()) {
    
    guard var request = Self.requestForm(data: data, urlString: endpoint, type: .POST) else {
      completion(nil, nil, nil)
      return
    }
    
    headers.forEach { (key, value) in
      request.addValue(value, forHTTPHeaderField: key)
    }
    
    URLSession.shared.dataTask(with: request) { (dataResp, response, error) in
      completion(dataResp, response, error)
    }.resume()
  }
  
  func post(endpoint: String,
            headers: [String: String] = [:],
            data: Data? = nil,
            completion: @escaping(_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?) -> ()) {
    
    guard var request = Self.request(data: data, urlString: endpoint, type: .POST) else {
      completion(nil, nil, nil)
      return
    }
    
    headers.forEach { (key, value) in
      request.addValue(value, forHTTPHeaderField: key)
    }
    
    URLSession.shared.dataTask(with: request) { (dataResp, response, error) in
      completion(dataResp, response, error)
    }.resume()
  }
  
  func get<TModel: Decodable>(endpoint: String,
                              headers: [String: String] = [:],
                              data: Data? = nil,
                              completion: @escaping(Result<TModel?, Error>?) -> ()) {
    
    guard var request = Self.request(data: data, urlString: endpoint, type: .GET) else {
      completion(.failure(HTTPError.loadError))
      return
    }
    
    headers.forEach { (key, value) in
      request.addValue(value, forHTTPHeaderField: key)
    }
    
    URLSession.shared.dataTask(with: request) { (dataResp, response, error) in
      guard error == nil else {
        completion(.failure(error ?? HTTPError.loadError))
        return
      }
      let result: Result<TModel?, Error> = Result { try self.decode(data: dataResp) }
      completion(result)
    }.resume()
  }
}
