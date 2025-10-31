//
//  PATools_Data_UpdaterTests.swift
//  PATools Data UpdaterTests
//
//  Created by Olivier Jobin on 30/10/2025.
//

import Foundation
import Testing
@testable import PATools_Data_Updater

struct AmpLoadDatasetValidationTests {

    @Test func validateRejectsDuplicateLoadModelNames() async throws {
        let amplifier = AmpLoadDataset.Amplifier(
            name: "Amplifier A",
            loads: [
                .init(modelName: "Load 1", nominalImpedance: 8),
                .init(modelName: "Load 1", nominalImpedance: 4)
            ]
        )

        let dataset = AmpLoadDataset(amplifiers: [amplifier])

        var thrownError: AmpLoadDataset.ValidationError?
        var unexpectedError: Error?
        do {
            try dataset.validate()
        } catch let error as AmpLoadDataset.ValidationError {
            thrownError = error
        } catch {
            unexpectedError = error
        }

        #expect(unexpectedError == nil)
        #expect(thrownError == .duplicateModelNames(["Amplifier A": ["Load 1"]]))
    }

    @Test func encodingRejectsDuplicateModelNames() async throws {
        let amplifier = AmpLoadDataset.Amplifier(
            name: "Amplifier B",
            loads: [
                .init(modelName: "Load X", nominalImpedance: 16),
                .init(modelName: "Load X", nominalImpedance: 32)
            ]
        )

        let dataset = AmpLoadDataset(amplifiers: [amplifier])

        var thrownError: AmpLoadDataset.ValidationError?
        var unexpectedError: Error?
        do {
            _ = try JSONEncoder().encode(dataset)
        } catch let error as AmpLoadDataset.ValidationError {
            thrownError = error
        } catch {
            unexpectedError = error
        }

        #expect(unexpectedError == nil)
        #expect(thrownError == .duplicateModelNames(["Amplifier B": ["Load X"]]))
    }
}
