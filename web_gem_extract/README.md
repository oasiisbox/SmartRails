# SmartRails Web Interface - Extraction

## Description

Ce dossier contient tous les composants web extraits du projet SmartRails principal pour créer la future gem `smartrails-web`.

## Contenu Extrait

### Fichiers Ruby
- **`lib/serve.rb`** : Commande Sinatra pour serveur web local
- **`lib/html_reporter.rb`** : Générateur de rapports HTML avec CSS intégré

### Templates et Vues
- **`views/index.erb`** : Interface principale pour visualiser les rapports
- **CSS intégré** : Styles responsive pour interface moderne

### Tests
- **`spec/cli_spec_serve_part.rb`** : Tests pour la commande serve

## Objectif : Gem `smartrails-web`

### Vision
Créer une gem complémentaire qui fournit :
- **Interface web locale** pour visualiser les rapports SmartRails
- **Génération HTML** avec styles professionnels
- **API REST** pour intégration avec d'autres outils
- **Visualisations interactives** des résultats d'audit

### Architecture Proposée

```ruby
# Gemfile future smartrails-web
gem 'smartrails-web'

# Usage
require 'smartrails/web'

# CLI intégré
smartrails-web serve --port 4567

# Programmatique  
SmartRails::Web::Server.new(reports_dir: "./reports").start
```

### Interopérabilité

- **Lecture des rapports JSON** générés par SmartRails CLI
- **Aucune dépendance** sur le code interne de SmartRails
- **Interface standardisée** via fichiers JSON/HTML
- **Compatible** avec toutes versions SmartRails

### Dépendances à Migrer

```ruby
# À ajouter dans smartrails-web.gemspec
spec.add_dependency 'sinatra', '~> 4.1'
spec.add_dependency 'puma', '~> 6.0'    # ou autre serveur web
spec.add_dependency 'json', '~> 2.0'
```

### Structure Gem Finale

```
smartrails-web/
├── lib/
│   ├── smartrails/
│   │   └── web/
│   │       ├── server.rb        # ex-serve.rb
│   │       ├── html_reporter.rb # ex-html_reporter.rb
│   │       └── version.rb
│   └── smartrails-web.rb        # Point d'entrée
├── views/
│   └── index.erb                # Interface web
├── bin/
│   └── smartrails-web           # CLI exécutable
├── spec/
├── README.md
└── smartrails-web.gemspec
```

## Actions Requises

### 1. Adaptation du Code
- [ ] Renommer classes/modules pour éviter conflits
- [ ] Adapter chemins et requires
- [ ] Créer CLI indépendant
- [ ] Séparer configuration

### 2. Tests Indépendants  
- [ ] Tests unitaires pour serveur web
- [ ] Tests d'intégration avec rapports JSON
- [ ] Tests interface utilisateur

### 3. Documentation
- [ ] README complet avec exemples
- [ ] Documentation API
- [ ] Guide d'intégration

### 4. Publication
- [ ] Configuration RubyGems
- [ ] CI/CD indépendant
- [ ] Versioning sémantique

## Compatibilité

Cette gem web sera compatible avec :
- **SmartRails Core** : Lecture des rapports JSON standard
- **Rails 6+** : Interface pour projets Rails modernes  
- **Ruby 2.7+** : Support des versions récentes
- **Serveurs Web** : Puma, Thin, WEBrick selon besoins

## Maintenance

**Maintenu par** : OASIISBOX
**Licence** : MIT (identique au projet principal)
**Stratégie** : Release indépendante, cycle de vie séparé

---

**Note** : Ce dossier est temporaire et sera migré vers un repository séparé pour la gem `smartrails-web`.