# SmartRails Architecture

Ce document décrit l'architecture et l'organisation du projet SmartRails.

## 📁 Structure des dossiers

```
smartrails/
├── bin/                          # Exécutables CLI
│   └── smartrails               # Point d'entrée principal
├── lib/                         # Code source principal
│   ├── smartrails.rb           # Point d'entrée de la gem
│   └── smartrails/             # Modules principaux
│       ├── version.rb          # Gestion des versions
│       ├── cli.rb              # Interface en ligne de commande (Thor)
│       ├── auditors/           # Modules d'audit
│       │   ├── base_auditor.rb
│       │   ├── security_auditor.rb
│       │   ├── performance_auditor.rb
│       │   └── code_quality_auditor.rb
│       ├── commands/           # Commandes CLI
│       │   ├── base.rb
│       │   ├── init.rb
│       │   ├── audit.rb
│       │   ├── suggest.rb
│       │   └── serve.rb
│       ├── reporters/          # Générateurs de rapports
│       │   ├── json_reporter.rb
│       │   └── html_reporter.rb
│       ├── suggestors/         # Intégrations IA
│       │   ├── base_suggestor.rb
│       │   ├── ollama_suggestor.rb
│       │   └── openai_suggestor.rb
│       └── views/              # Templates web
│           └── index.erb
├── spec/                       # Tests RSpec
│   ├── spec_helper.rb
│   ├── support/
│   └── smartrails/
│       ├── auditors/
│       ├── commands/
│       ├── reporters/
│       └── suggestors/
├── docs/                       # Documentation
├── examples/                   # Exemples d'utilisation
├── reports/                    # Rapports générés (gitignore)
├── logs/                       # Logs d'exécution (gitignore)
└── Configuration files:
    ├── Gemfile                 # Dépendances Ruby
    ├── smartrails.gemspec      # Spécification de la gem
    ├── Rakefile                # Tâches automatisées
    ├── .gitignore              # Fichiers ignorés par Git
    ├── .rubocop.yml            # Configuration qualité code
    ├── .rspec                  # Configuration tests RSpec
    ├── README.md               # Documentation principale
    ├── CHANGELOG.md            # Historique des versions
    ├── CONTRIBUTING.md         # Guide de contribution
    ├── LICENSE                 # Licence MIT
    └── CODE_OF_CONDUCT.md      # Code de conduite
```

## 🏗️ Architecture des modules

### 1. **CLI (Command Line Interface)**
- **Fichier**: `lib/smartrails/cli.rb`
- **Framework**: Thor
- **Responsabilité**: Point d'entrée principal, gestion des commandes et options

### 2. **Auditors (Auditeurs)**
- **Dossier**: `lib/smartrails/auditors/`
- **Pattern**: Strategy Pattern
- **Classes**:
  - `BaseAuditor`: Classe parent abstraite
  - `SecurityAuditor`: Audits de sécurité (CSRF, SQL injection, etc.)
  - `PerformanceAuditor`: Audits de performance (N+1, indexes, cache)
  - `CodeQualityAuditor`: Qualité du code (tests, documentation, linting)

### 3. **Commands (Commandes)**
- **Dossier**: `lib/smartrails/commands/`
- **Pattern**: Command Pattern
- **Classes**:
  - `Base`: Classe parent pour toutes les commandes
  - `Init`: Initialisation de projet
  - `Audit`: Exécution des audits
  - `Suggest`: Suggestions IA
  - `Serve`: Interface web

### 4. **Reporters (Générateurs de rapports)**
- **Dossier**: `lib/smartrails/reporters/`
- **Pattern**: Factory Pattern
- **Classes**:
  - `JsonReporter`: Rapports JSON structurés
  - `HtmlReporter`: Rapports HTML avec CSS

### 5. **Suggestors (Intégrations IA)**
- **Dossier**: `lib/smartrails/suggestors/`
- **Pattern**: Adapter Pattern
- **Classes**:
  - `BaseSuggestor`: Interface commune
  - `OllamaSuggestor`: Intégration Ollama (local)
  - `OpenAISuggestor`: Intégration OpenAI GPT

## 🔄 Flux d'exécution

### Audit complet
```
1. CLI parse les arguments
2. Commands::Audit initialise les auditeurs
3. Chaque auditor analyse le projet Rails
4. Les issues sont collectées et agrégées
5. Reporter génère le rapport final
6. Auto-fix applique les corrections (optionnel)
```

### Suggestion IA
```
1. CLI parse les arguments et options
2. Commands::Suggest charge le rapport ou fichier
3. Suggestor approprié est instancié
4. Analyse IA du code/rapport
5. Suggestions formatées et affichées
```

## 🧩 Patterns et principes

### Design Patterns utilisés
- **Strategy Pattern**: Auditeurs interchangeables
- **Command Pattern**: Commandes CLI modulaires
- **Factory Pattern**: Création de reporters
- **Adapter Pattern**: Intégrations IA diverses
- **Template Method**: BaseAuditor définit le workflow

### Principes SOLID
- **S**: Chaque classe a une responsabilité unique
- **O**: Extension sans modification (nouveaux auditeurs)
- **L**: Substitution des implémentations (reporters, suggestors)
- **I**: Interfaces spécialisées (BaseAuditor, BaseSuggestor)
- **D**: Inversion de dépendance (injection des auditeurs)

## 📊 Modèle de données

### Structure d'un Issue
```ruby
{
  type: "CSRF Protection",           # Type de problème
  message: "Description détaillée", # Message explicatif
  severity: :high,                  # :critical, :high, :medium, :low
  file: "app/controllers/...",      # Fichier concerné
  line: 42,                         # Ligne (optionnel)
  auto_fixable: true,              # Correction automatique possible
  auto_fix: lambda { ... },        # Fonction de correction
  metadata: { ... }                # Données additionnelles
}
```

### Structure d'un rapport
```ruby
{
  timestamp: "2024-01-15T10:30:00Z",
  version: "0.3.0",
  summary: "Résumé textuel",
  statistics: {
    total: 12,
    by_severity: { critical: 0, high: 5, medium: 4, low: 3 },
    auto_fixable: 8
  },
  issues: [...],                   # Array d'issues
  metadata: {
    rails_version: "7.0.4",
    ruby_version: "3.2.0",
    execution_time: 2.3
  }
}
```

## 🔧 Configuration

### Variables d'environnement
- `OLLAMA_MODEL`: Modèle Ollama par défaut
- `OPENAI_API_KEY`: Clé API OpenAI
- `SMARTRAILS_REPORTS_DIR`: Dossier des rapports

### Fichier de configuration (.smartrails.json)
```json
{
  "name": "my_project",
  "version": "0.3.0",
  "features": ["security", "performance", "quality"],
  "rails_version": "7.0.4",
  "ruby_version": "3.2.0",
  "custom_rules": {
    "security": {
      "check_api_authentication": true
    }
  }
}
```

## 🧪 Tests

### Structure des tests
- **Unit tests**: Tests isolés de chaque classe
- **Integration tests**: Tests des workflows complets
- **Mock/Stub**: Isolation des dépendances externes

### Couverture de code
- Objectif: 95%+ de couverture
- Tool: SimpleCov
- Exclusions: fichiers de configuration, vues

## 🚀 Extensibilité

### Ajouter un nouvel auditeur
1. Créer `lib/smartrails/auditors/my_auditor.rb`
2. Hériter de `BaseAuditor`
3. Implémenter `#run`
4. Ajouter les tests correspondants
5. Enregistrer dans la commande `audit`

### Ajouter un nouveau reporter
1. Créer `lib/smartrails/reporters/my_reporter.rb`
2. Implémenter les méthodes requises
3. Ajouter le format dans la CLI
4. Tests et documentation

### Ajouter un nouveau suggestor
1. Créer `lib/smartrails/suggestors/my_suggestor.rb`
2. Hériter de `BaseSuggestor`
3. Implémenter les méthodes d'API
4. Configuration et tests

## 📈 Performance

### Optimisations actuelles
- Exécution parallèle des audits (planned)
- Cache des résultats (planned)
- Lazy loading des modules
- Stream processing pour gros projets

### Métriques surveillées
- Temps d'exécution total
- Mémoire utilisée
- Nombre de fichiers analysés
- Temps par auditeur