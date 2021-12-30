//
//  API.swift
//  SwiftChat
//
//  Created by William Vabrinskas on 2/14/20.
//  Copyright © 2020 William Vabrinskas. All rights reserved.
//


import Foundation
import Combine

@available(iOS, deprecated: 15.0, message: "Use the built-in API instead")
extension URLSession {
  func data(from url: URL) async throws -> (Data, URLResponse) {
    try await withCheckedThrowingContinuation { continuation in
      let task = self.dataTask(with: url) { data, response, error in
        guard let data = data, let response = response else {
          let error = error ?? URLError(.badServerResponse)
          return continuation.resume(throwing: error)
        }
        
        continuation.resume(returning: (data, response))
      }
      
      task.resume()
    }
  }
  
  func data(from request: URLRequest) async throws -> (Data, URLResponse) {
    try await withCheckedThrowingContinuation { continuation in
      let task = self.dataTask(with: request) { data, response, error in
        guard let data = data, let response = response else {
          let error = error ?? URLError(.badServerResponse)
          return continuation.resume(throwing: error)
        }
        
        continuation.resume(returning: (data, response))
      }
      
      task.resume()
    }
  }
}

public enum RequestType: String {
  case GET
  case POST
}

public enum HTTPError: Error {
  case loadError
  case emptyData
  
  var localizedDescription: String {
    switch self {
    case .loadError:
      return "could not load data from response"
    case .emptyData:
      return "response from server was empty"
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
                              completion: @escaping(Result<TModel, Error>?) -> ())
  func decode<TModel: Decodable>(data: Data) throws -> TModel
  
  func get<TModel: Decodable>(endpoint: String,
                              urlSession: URLSession,
                              headers: [String: String],
                              data: Data?) -> AnyPublisher<Result<TModel, Error>, Error>
  
  func post<TModel: Decodable>(endpoint: String,
                               urlSession: URLSession,
                               headers: [String: String],
                               data: Data?) -> AnyPublisher<Result<TModel, Error>, Error>
  
  func get<TModel: Decodable>(endpoint: String,
                              urlSession: URLSession,
                              headers: [String: String],
                              data: Data?) async -> Result<TModel, Error>
  
  func post<TModel: Decodable>(endpoint: String,
                              urlSession: URLSession,
                              headers: [String: String],
                              data: Data?) async -> Result<TModel, Error>
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
  
  func decode<TModel: Decodable>(data: Data) throws -> TModel {
      do {
        let obj = try JSONDecoder().decode(TModel.self, from: data)
        return obj
      } catch {
        print(error.localizedDescription)
        throw error
      }
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
                              completion: @escaping(Result<TModel, Error>?) -> ()) {
    
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
      
      guard let dataResp = dataResp else {
        completion(.failure(HTTPError.emptyData))
        return
      }

      do {
        let model: TModel = try self.decode(data: dataResp)
        completion(.success(model))
      } catch {
        completion(.failure(error))
      }
    }.resume()
  }
  
  func get<TModel: Decodable>(endpoint: String,
                              urlSession: URLSession = .shared,
                              headers: [String: String] = [:],
                              data: Data? = nil) -> AnyPublisher<Result<TModel, Error>, Error> {
    
    guard let request = Self.request(data: data, urlString: endpoint, type: .GET) else {
      return AnyPublisher(Fail<Result<TModel, Error>, Error>(error: URLError.init(.cannotFindHost)))
    }
    
    return self.dataPublisher(request: request, session: urlSession)
  }
  
  func post<TModel: Decodable>(endpoint: String,
                               urlSession: URLSession = .shared,
                               headers: [String: String] = [:],
                               data: Data? = nil) -> AnyPublisher<Result<TModel, Error>, Error> {
    
    guard var request = Self.request(data: data, urlString: endpoint, type: .POST) else {
      return AnyPublisher(Fail<Result<TModel, Error>, Error>(error: URLError.init(.cannotFindHost)))
    }
    
    headers.forEach { (key, value) in
      request.addValue(value, forHTTPHeaderField: key)
    }
    
    return self.dataPublisher(request: request, session: urlSession)
  }
  
  func get<TModel: Decodable>(endpoint: String,
                              urlSession: URLSession = .shared,
                              headers: [String: String] = [:],
                              data: Data? = nil) async -> Result<TModel, Error> {
    
    guard let request = Self.request(data: data, urlString: endpoint, type: .GET) else {
      return .failure(URLError(.cannotFindHost))
    }
    
    do {
      let (model, _) = try await urlSession.data(from: request)
      let decodedModel: TModel = try self.decode(data: model)
      return .success(decodedModel)
      
    } catch {
      print(error.localizedDescription)
      return .failure(URLError(.cannotParseResponse))
    }
  }
  
  func post<TModel: Decodable>(endpoint: String,
                              urlSession: URLSession = .shared,
                              headers: [String: String] = [:],
                              data: Data? = nil) async -> Result<TModel, Error> {
    
    guard var request = Self.request(data: data, urlString: endpoint, type: .POST) else {
      return .failure(URLError(.cannotFindHost))
    }
    
    headers.forEach { (key, value) in
      request.addValue(value, forHTTPHeaderField: key)
    }
    
    do {
      let (model, _) = try await urlSession.data(from: request)
      let decodedModel: TModel = try self.decode(data: model)
      return .success(decodedModel)
      
    } catch {
      print(error.localizedDescription)
      return .failure(URLError(.cannotParseResponse))
    }
  }
  
  private func dataPublisher<TModel: Decodable>(request: URLRequest,
                                                session: URLSession = .shared) -> AnyPublisher<Result<TModel, Error>, Error> {
    let sessionPublisher = session.dataTaskPublisher(for: request)
      .subscribe(on: DispatchQueue.global())
      .tryMap() { element -> Data in
        guard let httpResponse = element.response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
              }
        return element.data
      }
      .tryMap() { element -> Result<TModel, Error> in
        do {
          let model = try JSONDecoder().decode(TModel.self, from: element)
          return .success(model)
        } catch {
          return .failure(error)
        }
      }
      .receive(on: DispatchQueue.main)
    
    return AnyPublisher(sessionPublisher)
  }
}
