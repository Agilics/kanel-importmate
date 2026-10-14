@isTest
private class LookupResolverTest {
    @isTest
    static void testResolveAndSkipInvalidEntries() {
        Account acc = new Account(Name = 'Lookup Acc');
        insert acc;

        Map<String, Map<String, Set<String>>> inputMap = new Map<String, Map<String, Set<String>>>{
            'Account' => new Map<String, Set<String>>{
                'Name' => new Set<String>{'Lookup Acc', 'Missing'},
                'BadField__c' => new Set<String>{'X'}
            },
            'NoObject__c' => new Map<String, Set<String>>{
                'Name' => new Set<String>{'Lookup Acc'}
            }
        };

        Map<String, Map<String, Map<String, Id>>> result = LookupResolver.resolve(inputMap);

        System.Assert.isTrue(result.containsKey('Account'));
        System.Assert.isTrue(result.get('Account').containsKey('Name'));
        System.Assert.areEqual(acc.Id, result.get('Account').get('Name').get('Lookup Acc'));
        System.Assert.isFalse(result.containsKey('NoObject__c'));
    }
}