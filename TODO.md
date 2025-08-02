# TODO - SmartRails Web Interface Separation

## ✅ Actions Réalisées

### Analyse et Extraction
- [x] **Identification des composants web** : serve.rb, views/, html_reporter.rb
- [x] **Création du dossier d'extraction** : `/web_gem_extract/`
- [x] **Extraction complète** : Tous les fichiers web copiés vers extraction
- [x] **Tests extraits** : Tests du serve command déplacés

### Nettoyage du Projet Principal
- [x] **Suppression des fichiers web** : serve.rb, views/ supprimés
- [x] **Nettoyage gemspec** : Dépendances Sinatra/Puma supprimées
- [x] **Mise à jour CLI** : Commande serve retirée
- [x] **Tests nettoyés** : Tests serve supprimés du CLI principal
- [x] **Documentation mise à jour** : README modifié avec références à smartrails-web

### Documentation
- [x] **README web gem** : Documentation complète dans /web_gem_extract/
- [x] **Architecture proposée** : Structure gem future définie
- [x] **Plan de migration** : Étapes détaillées documentées

## 🔄 Actions à Réaliser

### 1. Validation du CLI Core (Priorité Haute)
- [ ] **Tests CLI** : Vérifier que toutes commandes CLI fonctionnent
- [ ] **Génération rapports** : Audit + génération JSON/HTML
- [ ] **Dépendances** : Bundle install sans erreurs
- [ ] **Fonctionnalités core** : init, audit, suggest, check:llm

### 2. Création Gem smartrails-web (Priorité Haute)
- [ ] **Repository séparé** : Créer repo GitHub smartrails-web
- [ ] **Structure gem** : Gemspec, lib/, bin/, spec/ complètes
- [ ] **Adaptation code** : Namespace SmartRails::Web
- [ ] **CLI indépendant** : Exécutable smartrails-web
- [ ] **Tests complets** : Suite de tests indépendante

### 3. Interopérabilité (Priorité Moyenne)  
- [ ] **Format JSON standard** : Assurer compatibilité rapports
- [ ] **API stable** : Interface standardisée entre gems
- [ ] **Configuration partagée** : Répertoires rapports compatibles
- [ ] **Versioning** : Stratégie de compatibilité

### 4. Publication et Distribution (Priorité Moyenne)
- [ ] **CI/CD séparé** : GitHub Actions pour smartrails-web
- [ ] **RubyGems publication** : gem install smartrails-web
- [ ] **Documentation utilisateur** : Guide d'installation et usage
- [ ] **Tests d'intégration** : Validation E2E entre les deux gems

### 5. Migration Utilisateurs (Priorité Basse)
- [ ] **Guide de migration** : Docs pour utilisateurs existants
- [ ] **Dépréciation gracieuse** : Messages d'info dans SmartRails core
- [ ] **Compatibilité descendante** : Transition en douceur
- [ ] **Communication** : Annonce community

## 📋 Fichiers dans /web_gem_extract/

### Composants Ruby
```
web_gem_extract/
├── lib/
│   ├── serve.rb              # Serveur Sinatra (ex commands/serve.rb)
│   └── html_reporter.rb      # Générateur HTML (ex reporters/html_reporter.rb)
├── views/
│   └── index.erb             # Interface web principale
├── spec/
│   └── cli_spec_serve_part.rb # Tests pour serve command
└── README.md                 # Documentation complète
```

### Dépendances à Migrer
- **sinatra** (~> 4.1) : Serveur web
- **puma** (~> 6.0) : Serveur HTTP
- **json** (~> 2.0) : Parsing rapports

## 🔧 Configuration Technique

### SmartRails Core (CLI)
- **Focus** : Audit, suggestions, génération rapports
- **Sorties** : JSON, HTML statique  
- **CLI** : smartrails init|audit|suggest|check:llm
- **Dépendances** : Thor, TTY, RuboCop, auditors only

### SmartRails Web (Interface)
- **Focus** : Visualisation, serveur web local, API
- **Entrées** : Rapports JSON de SmartRails core
- **CLI** : smartrails-web serve [options]
- **Dépendances** : Sinatra, Puma, web assets

## ⚠️ Points d'Attention

### Compatibilité
- **Format rapports** : Maintenir structure JSON stable
- **Chemins relatifs** : Configuration répertoires rapports
- **Versions Ruby** : Support identique (2.7+)

### Tests
- **Tests CLI** : Vérifier aucune régression
- **Tests Web** : Serveur + interface fonctionnels
- **Tests Intégration** : Workflow complet

### Documentation
- **README principal** : Références claires à smartrails-web
- **Migration docs** : Guide pour utilisateurs existants
- **API docs** : Interface entre les deux gems

## 🎯 Critères de Succès

1. **CLI SmartRails** : Fonctionne 100% sans composants web
2. **Gem smartrails-web** : Installation et usage indépendants  
3. **Interopérabilité** : Lecture fluide des rapports entre gems
4. **Tests** : Couverture complète et CI/CD séparés
5. **Documentation** : Guides utilisateur complets
6. **Publication** : Disponible sur RubyGems

---

**Maintenu par** : OASIISBOX.SmartRailsDEV  
**Créé** : Août 2025  
**Dernière mise à jour** : Séparation initiale réalisée