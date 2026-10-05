import Testing
@testable import IPTVCore

@Test func itemTypesAreExactlyThree() { #expect(ItemType.allCases.count == 3) }
