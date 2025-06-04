-- WorldWideImporters Sample Data for Azure SQL Database
-- This script creates a simplified version of WorldWideImporters tables and sample data
-- Compatible with Azure SQL Database

PRINT 'Creating sample WorldWideImporters tables for Azure SQL Database...'

-- Create sample schemas
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Sales')
    EXEC('CREATE SCHEMA Sales')

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Purchasing')
    EXEC('CREATE SCHEMA Purchasing')

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Warehouse')
    EXEC('CREATE SCHEMA Warehouse')

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Application')
    EXEC('CREATE SCHEMA Application')

-- Create sample tables
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Customers' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE TABLE Sales.Customers (
        CustomerID INT IDENTITY(1,1) PRIMARY KEY,
        CustomerName NVARCHAR(100) NOT NULL,
        BillToCustomerID INT,
        CustomerCategoryID INT,
        PrimaryContactPersonID INT,
        DeliveryMethodID INT,
        DeliveryCityID INT,
        PostalCityID INT,
        AccountOpenedDate DATE,
        StandardDiscountPercentage DECIMAL(18,3),
        IsStatementSent BIT,
        IsOnCreditHold BIT,
        PaymentDays INT,
        PhoneNumber NVARCHAR(20),
        FaxNumber NVARCHAR(20),
        WebsiteURL NVARCHAR(256),
        DeliveryAddressLine1 NVARCHAR(60),
        DeliveryPostalCode NVARCHAR(10),
        PostalAddressLine1 NVARCHAR(60),
        PostalPostalCode NVARCHAR(10),
        LastEditedBy INT,
        ValidFrom DATETIME2(7) DEFAULT SYSDATETIME(),
        ValidTo DATETIME2(7) DEFAULT '9999-12-31 23:59:59.9999999'
    )
    
    PRINT 'Created Sales.Customers table'
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Orders' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE TABLE Sales.Orders (
        OrderID INT IDENTITY(1,1) PRIMARY KEY,
        CustomerID INT NOT NULL,
        SalespersonPersonID INT,
        PickedByPersonID INT,
        ContactPersonID INT,
        BackorderOrderID INT,
        OrderDate DATE,
        ExpectedDeliveryDate DATE,
        CustomerPurchaseOrderNumber NVARCHAR(20),
        IsUndersupplyBackordered BIT,
        Comments NVARCHAR(MAX),
        DeliveryInstructions NVARCHAR(MAX),
        InternalComments NVARCHAR(MAX),
        PickingCompletedWhen DATETIME2(7),
        LastEditedBy INT,
        LastEditedWhen DATETIME2(7) DEFAULT SYSDATETIME(),
        FOREIGN KEY (CustomerID) REFERENCES Sales.Customers(CustomerID)
    )
    
    PRINT 'Created Sales.Orders table'
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'OrderLines' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE TABLE Sales.OrderLines (
        OrderLineID INT IDENTITY(1,1) PRIMARY KEY,
        OrderID INT NOT NULL,
        StockItemID INT NOT NULL,
        Description NVARCHAR(100),
        PackageTypeID INT,
        Quantity INT,
        UnitPrice DECIMAL(18,2),
        TaxRate DECIMAL(18,3),
        PickedQuantity INT,
        PickingCompletedWhen DATETIME2(7),
        LastEditedBy INT,
        LastEditedWhen DATETIME2(7) DEFAULT SYSDATETIME(),
        FOREIGN KEY (OrderID) REFERENCES Sales.Orders(OrderID)
    )
    
    PRINT 'Created Sales.OrderLines table'
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'StockItems' AND schema_id = SCHEMA_ID('Warehouse'))
BEGIN
    CREATE TABLE Warehouse.StockItems (
        StockItemID INT IDENTITY(1,1) PRIMARY KEY,
        StockItemName NVARCHAR(100) NOT NULL,
        SupplierID INT,
        ColorID INT,
        UnitPackageID INT,
        OuterPackageID INT,
        Brand NVARCHAR(50),
        Size NVARCHAR(20),
        LeadTimeDays INT,
        QuantityPerOuter INT,
        IsChillerStock BIT,
        Barcode NVARCHAR(50),
        TaxRate DECIMAL(18,3),
        UnitPrice DECIMAL(18,2),
        RecommendedRetailPrice DECIMAL(18,2),
        TypicalWeightPerUnit DECIMAL(18,3),
        MarketingComments NVARCHAR(MAX),
        InternalComments NVARCHAR(MAX),
        CustomFields NVARCHAR(MAX),
        Tags NVARCHAR(MAX),
        SearchDetails NVARCHAR(MAX),
        LastEditedBy INT,
        ValidFrom DATETIME2(7) DEFAULT SYSDATETIME(),
        ValidTo DATETIME2(7) DEFAULT '9999-12-31 23:59:59.9999999'
    )
    
    PRINT 'Created Warehouse.StockItems table'
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Suppliers' AND schema_id = SCHEMA_ID('Purchasing'))
BEGIN
    CREATE TABLE Purchasing.Suppliers (
        SupplierID INT IDENTITY(1,1) PRIMARY KEY,
        SupplierName NVARCHAR(100) NOT NULL,
        SupplierCategoryID INT,
        PrimaryContactPersonID INT,
        AlternateContactPersonID INT,
        DeliveryMethodID INT,
        DeliveryCityID INT,
        PostalCityID INT,
        SupplierReference NVARCHAR(20),
        BankAccountName NVARCHAR(50),
        BankAccountBranch NVARCHAR(50),
        BankAccountCode NVARCHAR(20),
        BankAccountNumber NVARCHAR(20),
        BankInternationalCode NVARCHAR(20),
        PaymentDays INT,
        InternalComments NVARCHAR(MAX),
        PhoneNumber NVARCHAR(20),
        FaxNumber NVARCHAR(20),
        WebsiteURL NVARCHAR(256),
        DeliveryAddressLine1 NVARCHAR(60),
        DeliveryPostalCode NVARCHAR(10),
        PostalAddressLine1 NVARCHAR(60),
        PostalPostalCode NVARCHAR(10),
        LastEditedBy INT,
        ValidFrom DATETIME2(7) DEFAULT SYSDATETIME(),
        ValidTo DATETIME2(7) DEFAULT '9999-12-31 23:59:59.9999999'
    )
    
    PRINT 'Created Purchasing.Suppliers table'
END

-- Insert sample data
PRINT 'Inserting sample data...'

-- Sample Customers
IF NOT EXISTS (SELECT * FROM Sales.Customers)
BEGIN
    INSERT INTO Sales.Customers (CustomerName, BillToCustomerID, CustomerCategoryID, PrimaryContactPersonID, 
                                DeliveryMethodID, DeliveryCityID, PostalCityID, AccountOpenedDate, 
                                StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays,
                                PhoneNumber, WebsiteURL, DeliveryAddressLine1, DeliveryPostalCode,
                                PostalAddressLine1, PostalPostalCode, LastEditedBy)
    VALUES 
        ('Tailspin Toys (Head Office)', 1, 3, 1001, 3, 19586, 19586, '2013-01-01', 0.000, 0, 0, 7, '(308) 555-0100', 'http://www.tailspintoys.com', '90 Vogel Street', '90410', '90 Vogel Street', '90410', 1),
        ('Tailspin Toys (Sylvanite, MT)', 1, 3, 1002, 3, 19586, 19586, '2013-01-01', 0.000, 0, 0, 7, '(406) 555-0100', 'http://www.tailspintoys.com', '1877 Mittel Drive', '59041', '1877 Mittel Drive', '59041', 1),
        ('Tailspin Toys (Peeples Valley, AZ)', 1, 3, 1003, 3, 19586, 19586, '2013-01-01', 0.000, 0, 0, 7, '(928) 555-0100', 'http://www.tailspintoys.com', '2491 Carson Street', '86334', '2491 Carson Street', '86334', 1),
        ('Tailspin Toys (Medicine Lodge, KS)', 1, 3, 1004, 3, 19586, 19586, '2013-01-01', 0.000, 0, 0, 7, '(620) 555-0100', 'http://www.tailspintoys.com', '1234 Gussman Road', '67104', '1234 Gussman Road', '67104', 1),
        ('Tailspin Toys (Gasport, NY)', 1, 3, 1005, 3, 19586, 19586, '2013-01-01', 0.000, 0, 0, 7, '(716) 555-0100', 'http://www.tailspintoys.com', '5678 River Road', '14067', '5678 River Road', '14067', 1),
        ('Wingtip Toys (Head Office)', 2, 3, 1006, 3, 19586, 19586, '2013-01-01', 0.000, 0, 0, 7, '(425) 555-0100', 'http://www.wingtiptoys.com', '1234 Main Street', '98052', '1234 Main Street', '98052', 1),
        ('Adventure Works Cycles', 3, 2, 1007, 2, 19586, 19586, '2013-02-15', 5.000, 1, 0, 14, '(206) 555-0100', 'http://www.adventure-works.com', '4567 Cycle Lane', '98101', '4567 Cycle Lane', '98101', 1),
        ('Contoso Retail', 4, 1, 1008, 1, 19586, 19586, '2013-03-01', 2.500, 1, 0, 30, '(212) 555-0100', 'http://www.contoso.com', '789 Retail Blvd', '10001', '789 Retail Blvd', '10001', 1)
    
    PRINT 'Inserted sample customer data'
END

-- Sample Suppliers
IF NOT EXISTS (SELECT * FROM Purchasing.Suppliers)
BEGIN
    INSERT INTO Purchasing.Suppliers (SupplierName, SupplierCategoryID, PrimaryContactPersonID, 
                                     DeliveryMethodID, DeliveryCityID, PostalCityID, PaymentDays,
                                     PhoneNumber, WebsiteURL, DeliveryAddressLine1, DeliveryPostalCode,
                                     PostalAddressLine1, PostalPostalCode, LastEditedBy)
    VALUES 
        ('A Datum Corporation', 2, 2001, 7, 38171, 38171, 30, '(425) 555-0187', 'http://www.adatum.com', '123 Supply Street', '98052', '123 Supply Street', '98052', 1),
        ('Fabrikam, Inc.', 4, 2002, 7, 38171, 38171, 14, '(206) 555-0199', 'http://www.fabrikam.com', '456 Fabric Lane', '98101', '456 Fabric Lane', '98101', 1),
        ('Litware, Inc.', 6, 2003, 7, 38171, 38171, 21, '(212) 555-0145', 'http://www.litware.com', '789 Lit Avenue', '10001', '789 Lit Avenue', '10001', 1),
        ('Northwind Traders', 8, 2004, 7, 38171, 38171, 7, '(503) 555-0134', 'http://www.northwindtraders.com', '321 Trade Road', '97201', '321 Trade Road', '97201', 1)
    
    PRINT 'Inserted sample supplier data'
END

-- Sample Stock Items
IF NOT EXISTS (SELECT * FROM Warehouse.StockItems)
BEGIN
    INSERT INTO Warehouse.StockItems (StockItemName, SupplierID, UnitPackageID, OuterPackageID,
                                     Brand, Size, LeadTimeDays, QuantityPerOuter, IsChillerStock, TaxRate,
                                     UnitPrice, RecommendedRetailPrice, TypicalWeightPerUnit, LastEditedBy)
    VALUES 
        ('32 mm Anti static bubble wrap (1m roll)', 1, 7, 7, 'Generic', '1m roll', 14, 1, 0, 15.000, 3.70, 5.90, 0.050, 1),
        ('32 mm Anti static bubble wrap (10m roll)', 1, 7, 7, 'Generic', '10m roll', 14, 1, 0, 15.000, 32.00, 52.00, 0.500, 1),
        ('40 mm Double sided bubble wrap (1m roll)', 1, 7, 7, 'Generic', '1m roll', 14, 1, 0, 15.000, 4.70, 7.90, 0.060, 1),
        ('40 mm Double sided bubble wrap (10m roll)', 1, 7, 7, 'Generic', '10m roll', 14, 1, 0, 15.000, 41.00, 67.00, 0.600, 1),
        ('DHL 48 hour Courier', 2, 7, 7, 'DHL', 'ea', 2, 1, 0, 15.000, 15.00, 18.00, 0.300, 1),
        ('UPS Next Day Air', 2, 7, 7, 'UPS', 'ea', 1, 1, 0, 15.000, 25.00, 30.00, 0.250, 1),
        ('FedEx 2Day', 2, 7, 7, 'FedEx', 'ea', 2, 1, 0, 15.000, 18.00, 22.00, 0.275, 1),
        ('USB-C Cable (1m)', 3, 8, 8, 'TechCorp', '1m', 7, 10, 0, 15.000, 12.50, 19.99, 0.100, 1),
        ('HDMI Cable (2m)', 3, 8, 8, 'TechCorp', '2m', 7, 5, 0, 15.000, 15.75, 24.99, 0.150, 1),
        ('Ethernet Cable Cat6 (5m)', 3, 8, 8, 'NetCorp', '5m', 10, 20, 0, 15.000, 8.25, 12.99, 0.200, 1)
    
    PRINT 'Inserted sample stock items data'
END

-- Sample Orders
IF NOT EXISTS (SELECT * FROM Sales.Orders)
BEGIN
    INSERT INTO Sales.Orders (CustomerID, SalespersonPersonID, ContactPersonID, OrderDate, 
                             ExpectedDeliveryDate, CustomerPurchaseOrderNumber, 
                             IsUndersupplyBackordered, Comments, LastEditedBy)
    VALUES 
        (1, 3001, 1001, '2024-01-15', '2024-01-20', 'PO-001234', 0, 'First order from Head Office', 1),
        (2, 3002, 1002, '2024-01-16', '2024-01-22', 'PO-001235', 0, 'Monthly supply order', 1),
        (3, 3001, 1003, '2024-01-17', '2024-01-24', 'PO-001236', 0, 'Quarterly bulk order', 1),
        (7, 3003, 1007, '2024-01-18', '2024-01-25', 'AW-5678', 0, 'Adventure Works monthly supplies', 1),
        (8, 3002, 1008, '2024-01-19', '2024-01-26', 'CON-9999', 0, 'Contoso retail inventory', 1)
    
    PRINT 'Inserted sample orders data'
END

-- Sample Order Lines
IF NOT EXISTS (SELECT * FROM Sales.OrderLines)
BEGIN
    INSERT INTO Sales.OrderLines (OrderID, StockItemID, Description, Quantity, UnitPrice, TaxRate, LastEditedBy)
    VALUES 
        (1, 1, '32 mm Anti static bubble wrap (1m roll)', 10, 3.70, 15.000, 1),
        (1, 3, '40 mm Double sided bubble wrap (1m roll)', 5, 4.70, 15.000, 1),
        (1, 5, 'DHL 48 hour Courier', 1, 15.00, 15.000, 1),
        (2, 2, '32 mm Anti static bubble wrap (10m roll)', 3, 32.00, 15.000, 1),
        (2, 4, '40 mm Double sided bubble wrap (10m roll)', 2, 41.00, 15.000, 1),
        (3, 8, 'USB-C Cable (1m)', 50, 12.50, 15.000, 1),
        (3, 9, 'HDMI Cable (2m)', 25, 15.75, 15.000, 1),
        (3, 10, 'Ethernet Cable Cat6 (5m)', 100, 8.25, 15.000, 1),
        (4, 1, '32 mm Anti static bubble wrap (1m roll)', 20, 3.70, 15.000, 1),
        (4, 6, 'UPS Next Day Air', 2, 25.00, 15.000, 1),
        (5, 7, 'FedEx 2Day', 3, 18.00, 15.000, 1),
        (5, 8, 'USB-C Cable (1m)', 75, 12.50, 15.000, 1)
    
    PRINT 'Inserted sample order lines data'
END

-- Create some useful views
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'CustomerOrderSummary')
BEGIN
    EXEC('CREATE VIEW Sales.CustomerOrderSummary AS
    SELECT 
        c.CustomerID,
        c.CustomerName,
        COUNT(o.OrderID) as TotalOrders,
        COALESCE(SUM(ol.Quantity * ol.UnitPrice), 0) as TotalValue,
        MAX(o.OrderDate) as LastOrderDate
    FROM Sales.Customers c
    LEFT JOIN Sales.Orders o ON c.CustomerID = o.CustomerID
    LEFT JOIN Sales.OrderLines ol ON o.OrderID = ol.OrderID
    GROUP BY c.CustomerID, c.CustomerName')
    
    PRINT 'Created Sales.CustomerOrderSummary view'
END

-- Display summary information
PRINT ''
PRINT '=== WorldWideImporters Sample Database Summary ==='
PRINT 'Database has been successfully created with sample data!'
PRINT ''

SELECT 'Customers' as TableName, COUNT(*) as RecordCount FROM Sales.Customers
UNION ALL
SELECT 'Suppliers', COUNT(*) FROM Purchasing.Suppliers
UNION ALL
SELECT 'StockItems', COUNT(*) FROM Warehouse.StockItems
UNION ALL
SELECT 'Orders', COUNT(*) FROM Sales.Orders
UNION ALL
SELECT 'OrderLines', COUNT(*) FROM Sales.OrderLines

PRINT ''
PRINT '=== Customer Order Summary ==='
SELECT * FROM Sales.CustomerOrderSummary ORDER BY TotalValue DESC

PRINT ''
PRINT 'Sample WorldWideImporters data created successfully for Azure SQL Database!'
PRINT 'This is a simplified version suitable for demonstration and development.'
PRINT ''
PRINT 'For the full WorldWideImporters database with complete data:'
PRINT '1. Download the BACPAC file from: https://github.com/Microsoft/sql-server-samples/releases/'
PRINT '2. Import it using Azure portal, Azure CLI, or SQL Server Management Studio'
PRINT '3. BACPAC files are the recommended way to import databases into Azure SQL Database'
