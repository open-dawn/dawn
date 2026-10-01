//
//  ListedApp.swift
//  pineapplewm
//
//  Created by Longhi on 28/09/26.
//

struct ListedApp: Identifiable, Codable, Sendable {
    var id: Int { path.hashValue }
    let name: String
    let path: String
    let obtainedFrom: String
    let lastModified: String
    
    enum CodingKeys: String, CodingKey {
        case name = "_name"
        case path
        case obtainedFrom = "obtained_from"
        case lastModified
    }
}