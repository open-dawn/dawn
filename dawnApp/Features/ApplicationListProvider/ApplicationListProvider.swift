//
//  ApplicationListProvider.swift
//  pineapplewm
//
//  Created by Longhi on 28/09/26.
//

protocol ApplicationListProvider: Sendable {
    func getList() async -> [ListedApp]
}