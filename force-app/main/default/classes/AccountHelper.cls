/**********************************************************************************
* Name             AccountHelper.cls
* Author          Andres Pereyra
* Date            26/08/24
* Description     This is an Apex Class which is used mainly by two LWC components via wire service 
***********************************************************************************
* MODIFICATION LOG
* Version            Developer          Date               Description
* ------------------------------------------------------------------------------
* 1.0                Andres Pereyra     03 January 2025           Initial Creation 
* *********************************************************************************/

public without sharing class AccountHelper {
    
    public static void updateAccountRolesCounts(List<AccountContactRelation> accountContactRelationRecordsToProcess) {
        Set<Id> accountIds = new Set<Id>();
        List<Account_Change_Event__e> accountsEventList = new List<Account_Change_Event__e>();
        
        // Collect account IDs from the records to process
        for (AccountContactRelation acr : accountContactRelationRecordsToProcess) {
            if (acr.AccountId != null) {
                accountIds.add(acr.AccountId);
            }
        }
        
        // Query the related AccountContactRelations for the affected accounts
        List<Account> accountsList = [
            SELECT Id, Decision_Makers__c, Business_Users__c,
            (SELECT Id, Roles FROM AccountContactRelations)
            FROM Account
            WHERE Id IN :accountIds
        ];
        
        // Update the custom fields on the Account
        for (Account account : accountsList) {
            Integer decisionMakersCount = 0;
            Integer businessUsersCount = 0;
            
            for (AccountContactRelation acr : account.AccountContactRelations) {
                if (acr.Roles!= null && acr.Roles != '') {
                    // Split the Roles field by semicolon and check each value
                    List<String> roles = acr.Roles.split(';');
                    for (String role : roles) {
                        if (role.equals('Decision Maker')) { // Besluitvormer  --> Decision Maker
                            decisionMakersCount++;
                        } 
                        if (role.equals('Business User')) { // Zakelijke gebruiker --> Business User
                            businessUsersCount++;
                        }
                    }
                }
            }   
            account.Decision_Makers__c = decisionMakersCount;
            account.Business_Users__c = businessUsersCount;
            
            accountsEventList.add(new Account_Change_Event__e(AccountId__c = account.Id));
        }
        
        // Perform the DML operation to update the accounts
        if (!accountsList.isEmpty()) {
            Database.SaveResult[] saveResults = Database.update(accountsList, false);
            
            List<Database.Error> failedRecordsErrors = new List<Database.Error>();
            for (Database.SaveResult saveResult : saveResults) {
                if (!saveResult.isSuccess()) {
                    failedRecordsErrors.addAll(saveResult.getErrors());
                }
            }
            if (!failedRecordsErrors.isEmpty()) {
                for (Database.Error error : failedRecordsErrors) {
                    System.debug('AccountHelper.updateAccountCounts() - Failed Record Error: ' + error.getMessage());
                }
            } else {
                // Publish the Platform Event
                if (!accountsEventList.isEmpty()){
                    // Call method to publish events
                    List<Database.SaveResult> results = EventBus.publish(accountsEventList);
                    
                    // Inspect publishing result for each event
                    for (Database.SaveResult sr : results) {
                        if (sr.isSuccess()) {
                            System.debug('Successfully published event.');
                        } else {
                            for(Database.Error err : sr.getErrors()) {
                                System.debug('Error returned: ' + err.getStatusCode() + ' - ' + err.getMessage());
                            }
                        }  
                        
                    }
                }
            }
        }
    }
        
        
        public static void updateAccountRelatedObjectsCounts(Set<Id> accountIds, String relatedObjectName) {
            
            if (accountIds.isEmpty()) {
                return;
            }
            // Query the affected accounts and their related objects
            String query = 'SELECT Id, ';
            if (relatedObjectName == 'Opportunity') {
                query += 'OpportunitiesSum__c, (SELECT Id FROM Opportunities) ';
            } else if (relatedObjectName == 'AccountContactRelation') {
                query += 'AccountContactRelationSum__c, (SELECT Id FROM AccountContactRelations) ';
            } else if (relatedObjectName == 'Contact') {
                query += 'ContactsSum__c, (SELECT Id FROM Contacts) ';
            }
            query += 'FROM Account WHERE Id IN :accountIds';
            
            List<Account> accountsList = Database.query(query);
            
            /// Update the custom fields on the Account
            for (Account account : accountsList) {
                if(relatedObjectName == 'Opportunity'){ 
                    account.OpportunitiesSum__c = account.Opportunities.size();
                } else if (relatedObjectName == 'AccountContactRelation'){
                    account.AccountContactRelationSum__c = account.AccountContactRelations.size();
                } else if (relatedObjectName == 'Contact'){
                    account.ContactsSum__c = account.Contacts.size();
                    account.AccountContactRelationSum__c = account.Contacts.size();
                }
            }
            
            // Perform the DML operation to update the accounts
            if (!accountsList.isEmpty()) {
                Database.SaveResult[] saveResults = Database.update(accountsList, false);
                
                List<Database.Error> failedRecordsErrors = new List<Database.Error>();
                for (Database.SaveResult saveResult : saveResults) {
                    if (!saveResult.isSuccess()) {
                        failedRecordsErrors.addAll(saveResult.getErrors());
                    }
                }
                if (!failedRecordsErrors.isEmpty()) {
                    for (Database.Error error : failedRecordsErrors) {
                        System.debug('AccountHelper.updateAccountRelatedObjectsCounts() - Failed Record Error: ' + error.getMessage());
                    }
                }
            }
        }
    }