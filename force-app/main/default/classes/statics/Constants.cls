/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-23-2025
 * @last modified by  : khalidousowba
**/
public with sharing class Constants {
    public static final Integer STAGING_BATCH_SIZE = 2000;
    public static final Integer IMPORT_BATCH_SIZE_DRY_RUN = 5;
    public static final Integer IMPORT_BATCH_SIZE_IMPORT = 25;
    public static final Integer MAX_LOGS_PER_EXECUTION = 10000;

    public static final String BOOLEAN_TYPE = 'Boolean';
    public static final String DATE_TYPE = 'Date';
    public static final String DATETIME_TYPE = 'DateTime';
    public static final String NUMBER_TYPE = 'Number';

    public static final String TRUE_VALUE = 'true';
    public static final String FALSE_VALUE = 'false';

    public static final String SUCCESS_VALUE = 'success';
    public static final String ERROR_VALUE = 'error';

    public static final String INFO_VALUE = 'info';
    public static final String WARNING_VALUE = 'warning';

    public static final String EMAIL_VALUE = 'Email';
    public static final String PHONE_VALUE = 'Phone';
    public static final String URL_VALUE = 'URL';
    public static final String TEXT_VALUE = 'Text';
    public static final String CSV_VALUE = 'CSV';
    public static final String SEMICOLON_VALUE = 'Semicolon';
    public static final String COMMA_VALUE = 'Comma';
    public static final String TAB_VALUE = 'Tab';
    public static final String SPACE_VALUE = 'Space';
    public static final String NEWLINE_VALUE = 'Newline';

    public static final String TRUE_VALUES = 'trueValues';
    public static final String FALSE_VALUES = 'falseValues';

    public static final String TARGET_TYPE = 'targetType';

    public static final String FIELD_MAPPING = 'fieldMapping';
    public static final String TARGET_FIELD = 'targetField';
    public static final String SOURCE_FIELD = 'sourceField';

    public static final String EXECUTION_STATUS_COMPLETED = 'Completed';
    public static final String EXECUTION_STATUS_FAILED = 'Failed';
    public static final String EXECUTION_STATUS_IN_PROGRESS = 'InProgress';
    public static final String EXECUTION_STATUS_SUSPENDED = 'Suspended';
    public static final String EXECUTION_STATUS_PENDING = 'Pending';
    public static final String EXECUTION_STATUS_CANCELLED = 'Cancelled';

    public static final String EXECUTION_PHASE_STAGING = 'Staging';
    public static final String EXECUTION_PHASE_PREPROCESSING = 'PreProcessing';
    public static final String EXECUTION_PHASE_VALIDATING = 'Validating';
    public static final String EXECUTION_PHASE_IMPORTING = 'Importing';
    public static final String EXECUTION_PHASE_CLEANUP = 'Cleanup';
    public static final String EXECUTION_PHASE_COMPLETED = 'Completed';

    public static final Integer SYNC_THRESHOLD = 50;
    public static final Integer SMALL_BATCH_THRESHOLD = 5000;

    public static final Integer PREPROCESS_BATCH_SIZE = 200;
    public static final Integer IMPORT_DML_BATCH_SIZE = 200;
    public static final Integer CLEANUP_BATCH_SIZE = 2000;
    public static final Integer STAGING_RETENTION_DAYS = 2;

    public static final String TIER_SYNC = 'Sync';
    public static final String TIER_SMALL_BATCH = 'SmallBatch';
    public static final String TIER_FULL_PIPELINE = 'FullPipeline';

    public static final String EXECUTION_TYPE_VALIDATION = 'Validation';
    public static final String EXECUTION_TYPE_TRANSFORMATION = 'Transformation';
    public static final String EXECUTION_TYPE_IMPORT = 'Import';
    public static final String EXECUTION_TYPE_UPDATE = 'Update';
    public static final String EXECUTION_TYPE_DELETE = 'Delete';
    public static final String EXECUTION_TYPE_UPSERT = 'Upsert';    

    public static final String ERROR_TYPE_VALIDATION = 'Validation';
    public static final String ERROR_TYPE_TRANSFORMATION = 'Transformation';
    public static final String ERROR_TYPE_MAPPING = 'Field Mapping';
    public static final String ERROR_TYPE_EXECUTION = 'Execution';
    public static final String ERROR_TYPE_SCHEDULING = 'Scheduling';
    public static final String ERROR_TYPE_CONVERSION = 'Conversion';


    public static final String ERROR_CODE_APPLICATION = 'APPLICATION_ERROR';
    public static final String ERROR_CODE_VALIDATION = 'VALIDATION_ERROR';
    public static final String ERROR_CODE_MAPPING = 'MAPPING_ERROR';
    public static final String ERROR_CODE_TRANSFORMATION = 'TRANSFORMATION_ERROR';
    public static final String ERROR_CODE_EXECUTION = 'EXECUTION_ERROR';
    public static final String ERROR_CODE_SCHEDULING = 'SCHEDULING_ERROR';
    public static final String ERROR_CODE_CONVERSION = 'CONVERSION_ERROR';

    public static final String INVALID_PICKLIST_VALUE = 'INVALID_PICKLIST_VALUE';
    public static final String INVALID_EMAIL_FORMAT = 'INVALID_EMAIL_FORMAT';
    public static final String INVALID_PHONE_FORMAT = 'INVALID_PHONE_FORMAT';
    public static final String INVALID_URL_FORMAT = 'INVALID_URL_FORMAT';
    public static final String LOOKUP_VALUE_NOT_FOUND = 'LOOKUP_VALUE_NOT_FOUND';
    public static final String LOOKUP_RESOLUTION_ERROR = 'LOOKUP_RESOLUTION_ERROR';
    public static final String INVALID_DATE_FORMAT = 'INVALID_DATE_FORMAT';
    public static final String INVALID_DATETIME_FORMAT = 'INVALID_DATETIME_FORMAT';
    public static final String INVALID_NUMERIC_FORMAT = 'INVALID_NUMERIC_FORMAT';
    public static final String REQUIRED_FIELD_MISSING = 'REQUIRED_FIELD_MISSING';
    public static final String TRANSFORMATION_ERROR = 'TRANSFORMATION_ERROR';
    public static final String INVALID_BOOLEAN_FORMAT = 'INVALID_BOOLEAN_FORMAT';
    
    // Codes d'erreur supplémentaires pour ValidationService
    public static final String ERROR_CODE_VALUE_TOO_LONG = 'VALUE_TOO_LONG';
    public static final String ERROR_CODE_REQUIRED_FIELDS_MISSING = 'REQUIRED_FIELDS_MISSING';
    public static final String ERROR_CODE_BUSINESS_RULE_VIOLATION = 'BUSINESS_RULE_VIOLATION';
    public static final String ERROR_CODE_BUSINESS_RULE_EVALUATION_ERROR = 'BUSINESS_RULE_EVALUATION_ERROR';
    public static final String ERROR_CODE_FIELD_SIZE_TOO_LARGE = 'FIELD_SIZE_TOO_LARGE';
    public static final String ERROR_CODE_INVALID_NUMBER_FORMAT = 'INVALID_NUMBER_FORMAT';
    



    /**
     * Liste d’indicatifs connus avec la longueur du numéro local.
     * Permet de conserver une structure réaliste pour le numéro généré.
    */
    public static final Map<String, Integer> COUNTRY_CODE_DIGITS = new Map<String, Integer>{
        '+1' => 10,     // USA, Canada
        '+33' => 9,     // France
        '+221' => 9,    // Sénégal
        '+32' => 9,     // Belgique
        '+41' => 9,     // Suisse
        '+212' => 9,    // Maroc
        '+225' => 10,   // Côte d’Ivoire
        '+237' => 9,    // Cameroun
        '+44' => 10,    // Royaume-Uni
        '+49' => 10,    // Allemagne
        '+34' => 9,     // Espagne
        '+39' => 10,    // Italie
        '+351' => 9,    // Portugal
        '+216' => 8,    // Tunisie
        '+91' => 10,    // Inde
        '+86' => 11,    // Chine
        '+81' => 10,    // Japon
        '+61' => 9,     // Australie
        '+7' => 10,     // Russie
        '+254' => 9,    // Kenya
        '+233' => 9,    // Ghana
        '+234' => 10,   // Nigeria
        '+971' => 9,    // Émirats Arabes Unis
        '+90' => 10,    // Turquie
        '+48' => 9,     // Pologne
        '+30' => 10     // Grèce
    };


}
