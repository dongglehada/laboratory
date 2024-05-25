//
//  Provider.swift
//  Laboratory
//
//  Created by SeoJunYoung on 5/25/24.
//

import Foundation

protocol Provider {
    /// 특정 responsable이 존재하는 request
    func request<R: Decodable, E: RequesteResponsable>(with endpoint: E, completion: @escaping (Result<R, Error>) -> Void) where E.Response == R

    /// data를 얻는 request
    func request(_ url: URL, completion: @escaping (Result<Data, Error>) -> ())
}

class ProviderImpl: Provider {

    let session: URLSessionable
    init(session: URLSessionable = URLSession.shared) {
        self.session = session
    }
    
    deinit {
        print(self, "deinit")
    }
    
    func request<R: Decodable, E: RequesteResponsable>(with endpoint: E, completion: @escaping (Result<R, Error>) -> Void) where E.Response == R {
        do {
            let urlRequest = try endpoint.getUrlRequest()
            session.dataTask(with: urlRequest) { [weak self] data, response, error in
                self?.checkError(with: data, response, error) { result in
                    switch result {
                    case .success(let data):
                        guard let self = self else { return }
                        completion(self.decode(data: data))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }.resume()
        } catch {
            completion(.failure(NetworkError.urlRequest(error)))
        }
    }

    func request(_ url: URL, completion: @escaping (Result<Data, Error>) -> ()) {
        session.dataTask(with: url) { [weak self] data, response, error in
            self?.checkError(with: data, response, error, completion: { result in
                completion(result)
            })
        }.resume()
    }

    // Private

    private func checkError(with data: Data?, _ response: URLResponse?, _ error: Error?, completion: @escaping (Result<Data, Error>) -> ()) {
        
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let response = response as? HTTPURLResponse else {
            completion(.failure(NetworkError.unknownError))
            return
        }

        guard (200...299).contains(response.statusCode) else {
            completion(.failure(NetworkError.invalidHttpStatusCode(response.statusCode)))
            return
        }

        guard let data = data else {
            completion(.failure(NetworkError.emptyData))
            return
        }

        completion(.success((data)))
    }

    private func decode<T: Decodable>(data: Data) -> Result<T, Error> {
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return .success(decoded)
        } catch {
            return .failure(NetworkError.emptyData)
        }
    }
}

extension Encodable {
    func toDictionary() throws -> [String: Any]? {
        let data = try JSONEncoder().encode(self)
        let jsonData = try JSONSerialization.jsonObject(with: data)
        return jsonData as? [String: Any]
    }
}

protocol URLSessionable {
    func dataTask(with request: URLRequest,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
    func dataTask(with url: URL,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
}

extension URLSession: URLSessionable {}
