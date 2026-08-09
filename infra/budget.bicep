targetScope = 'subscription'

@description('Correo al que llegan las alertas de presupuesto.')
param contactEmail string

@description('Importe mensual en la moneda de facturación de la suscripción.')
param amount int = 10

@description('Primer día del mes en curso, formato YYYY-MM-DD.')
param startDate string

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: 'budget-lab-mensual'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    notifications: {
      Real_50: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [ contactEmail ]
      }
      Real_80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [ contactEmail ]
      }
      Real_100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: [ contactEmail ]
      }
      Previsto_100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [ contactEmail ]
      }
    }
  }
}
