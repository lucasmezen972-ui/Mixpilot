import Foundation

public enum HelpLocale: String, CaseIterable, Codable, Sendable {
    case french = "fr"
    case english = "en"
    case spanish = "es"
}

public enum HelpTopicID: String, CaseIterable, Codable, Sendable {
    case gettingStarted
    case djSoftware
    case connection
    case mappings
    case preparation
    case transitions
    case preflight
    case live
    case iphone
    case manualRecovery
    case emergencyPlayback
    case troubleshooting
}

public struct HelpTopic: Identifiable, Hashable, Sendable {
    public let id: HelpTopicID
    public let title: String
    public let summary: String
    public let body: String
    public let keywords: [String]
    public let relatedIncidentKinds: Set<IncidentKind>

    public init(
        id: HelpTopicID,
        title: String,
        summary: String,
        body: String,
        keywords: [String],
        relatedIncidentKinds: Set<IncidentKind> = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.body = body
        self.keywords = keywords
        self.relatedIncidentKinds = relatedIncidentKinds
    }
}

public struct HelpCenterCatalog: Sendable {
    public let locale: HelpLocale
    public let topics: [HelpTopic]

    public init(locale: HelpLocale) {
        self.locale = locale
        self.topics = Self.makeTopics(locale: locale)
    }

    public func topic(for id: HelpTopicID) -> HelpTopic? {
        topics.first { $0.id == id }
    }

    public func topics(for incident: IncidentKind) -> [HelpTopic] {
        topics.filter { $0.relatedIncidentKinds.contains(incident) }
    }

    public func search(_ query: String) -> [HelpTopic] {
        let normalized = Self.normalize(query)
        guard !normalized.isEmpty else { return topics }

        return topics.compactMap { topic -> (HelpTopic, Int)? in
            let title = Self.normalize(topic.title)
            let summary = Self.normalize(topic.summary)
            let body = Self.normalize(topic.body)
            let keywords = topic.keywords.map(Self.normalize)

            var score = 0
            if title == normalized { score += 100 }
            if title.contains(normalized) { score += 40 }
            if keywords.contains(where: { $0 == normalized }) { score += 35 }
            if keywords.contains(where: { $0.contains(normalized) }) { score += 20 }
            if summary.contains(normalized) { score += 12 }
            if body.contains(normalized) { score += 5 }
            return score > 0 ? (topic, score) : nil
        }
        .sorted {
            if $0.1 == $1.1 { return $0.0.title < $1.0.title }
            return $0.1 > $1.1
        }
        .map(\.0)
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeTopics(locale: HelpLocale) -> [HelpTopic] {
        switch locale {
        case .french: frenchTopics
        case .english: englishTopics
        case .spanish: spanishTopics
        }
    }

    private static let frenchTopics: [HelpTopic] = [
        HelpTopic(id: .gettingStarted, title: "Bien démarrer", summary: "Configurer MixPilot sans dépendance Internet.", body: "Choisissez le logiciel DJ, vérifiez les autorisations macOS, sélectionnez le périphérique MIDI virtuel puis lancez le préflight. Gardez toujours une sortie audio de secours disponible.", keywords: ["démarrage", "installation", "hors ligne"]),
        HelpTopic(id: .djSoftware, title: "Logiciel DJ", summary: "Sélectionner et vérifier Serato, rekordbox ou djay.", body: "MixPilot ne suppose jamais qu'une API privée existe. La détection vérifie l'application, sa version et la fenêtre attendue. Après une mise à jour du logiciel DJ, relancez le préflight et revalidez le mapping.", keywords: ["serato", "rekordbox", "djay", "version"], relatedIncidentKinds: [.backendUnavailable, .seratoUnavailable]),
        HelpTopic(id: .connection, title: "Connexion locale", summary: "Comprendre MIDI, audio et télécommande locale.", body: "Le Live reste utilisable sans Internet. MIDI et audio sont prioritaires. La télécommande iPhone est facultative et sa perte ne doit pas interrompre la lecture.", keywords: ["connexion", "réseau", "midi", "audio"], relatedIncidentKinds: [.internetLoss, .midiUnavailable, .audioSourceLost]),
        HelpTopic(id: .mappings, title: "Mappings", summary: "Valider les commandes avant le Live.", body: "Un mapping n'est fiable que si chaque commande produit un effet observé et attendu. Ne publiez pas de mapping stable sans validation matérielle. Après changement de contrôleur, de version ou de périphérique virtuel, recommencez la validation.", keywords: ["mapping", "commande", "validation", "contrôleur"], relatedIncidentKinds: [.midiUnavailable, .transitionMismatch]),
        HelpTopic(id: .preparation, title: "Préparation du set", summary: "Analyser les morceaux et préparer les transitions.", body: "Vérifiez les BPM, durées, profils, densités vocales et niveaux d'énergie. Les plans restent des recommandations et doivent être répétés avant une prestation réelle.", keywords: ["préparation", "analyse", "morceaux", "bpm"]),
        HelpTopic(id: .transitions, title: "Transitions", summary: "Comprendre les plans, la confiance et les protections.", body: "Chaque transition possède un type, une durée, une cible BPM, un score de confiance et des automations. Les volumes de deck servent de protection indépendante du crossfader.", keywords: ["transition", "crossfader", "volume", "confiance"], relatedIncidentKinds: [.transitionMismatch, .audioClipping]),
        HelpTopic(id: .preflight, title: "Préflight", summary: "Bloquer le démarrage lorsque les preuves sont insuffisantes.", body: "Le préflight contrôle le logiciel DJ, le mapping, les périphériques, l'audio, la sortie de secours et l'état courant. Corrigez les éléments bloquants avant d'activer le Live.", keywords: ["préflight", "vérification", "sécurité"]),
        HelpTopic(id: .live, title: "Mode Live", summary: "Surveiller l'état et reprendre la main immédiatement.", body: "Gardez le Mac alimenté, désactivez la veille et surveillez les niveaux. En cas de doute, reprenez la main manuellement. Une commande tardive ou dupliquée doit être ignorée ou réconciliée, jamais appliquée aveuglément.", keywords: ["live", "veille", "chauffe", "surveillance"], relatedIncidentKinds: [.powerDisconnected, .checkpointMismatch, .audioClipping]),
        HelpTopic(id: .iphone, title: "Télécommande iPhone", summary: "Utiliser l'iPhone comme interface facultative.", body: "L'iPhone complète le Mac mais ne pilote pas la continuité audio. Si la connexion tombe, le Live local continue. Réappairez uniquement après avoir vérifié que le Mac reste stable.", keywords: ["iphone", "télécommande", "appairage", "réseau"], relatedIncidentKinds: [.internetLoss]),
        HelpTopic(id: .manualRecovery, title: "Reprise manuelle", summary: "Reprendre le contrôle sans créer une seconde action.", body: "Utilisez la commande de reprise immédiate, stabilisez le deck audible, annulez les automations en attente puis vérifiez l'état réel du logiciel DJ avant de relancer l'autopilote.", keywords: ["reprise", "manuel", "contrôle"], relatedIncidentKinds: [.wrongTrack, .transitionMismatch, .checkpointMismatch]),
        HelpTopic(id: .emergencyPlayback, title: "Lecture de secours", summary: "Maintenir un son audible pendant une panne.", body: "La lecture de secours est un dernier filet. Préparez une source locale testée, indépendante du réseau et du logiciel DJ principal. Revenez au système principal seulement après observation d'un état stable.", keywords: ["secours", "silence", "urgence", "fallback"], relatedIncidentKinds: [.audioSilence, .audioSourceLost, .emergencyPlayerFailure]),
        HelpTopic(id: .troubleshooting, title: "Dépannage", summary: "Diagnostiquer sans masquer les erreurs.", body: "Notez l'heure, l'état, le backend, la version et le dernier effet observé. Exportez un diagnostic anonymisé. Ne considérez pas un retry comme une réussite sans confirmation d'effet.", keywords: ["dépannage", "diagnostic", "erreur", "retry"], relatedIncidentKinds: Set(IncidentKind.allCases))
    ]

    private static let englishTopics: [HelpTopic] = frenchTopics.map { topic in
        switch topic.id {
        case .gettingStarted: HelpTopic(id: topic.id, title: "Getting started", summary: "Configure MixPilot without an Internet dependency.", body: "Choose the DJ software, verify macOS permissions, select the virtual MIDI device, then run preflight. Always keep a tested emergency audio source available.", keywords: ["setup", "offline", "start"])
        case .djSoftware: HelpTopic(id: topic.id, title: "DJ software", summary: "Select and verify Serato, rekordbox or djay.", body: "MixPilot never assumes a private API exists. Detection checks the application, version and expected window. After a DJ software update, run preflight and validate the mapping again.", keywords: ["serato", "rekordbox", "djay", "version"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .connection: HelpTopic(id: topic.id, title: "Local connection", summary: "Understand MIDI, audio and the local remote.", body: "Live remains usable without Internet. MIDI and audio have priority. The iPhone remote is optional and losing it must not stop playback.", keywords: ["connection", "network", "midi", "audio"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .mappings: HelpTopic(id: topic.id, title: "Mappings", summary: "Validate commands before Live.", body: "A mapping is reliable only when every command produces the expected observed effect. Do not publish a stable mapping without hardware validation.", keywords: ["mapping", "command", "validation"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .preparation: HelpTopic(id: topic.id, title: "Set preparation", summary: "Analyse tracks and prepare transitions.", body: "Check BPM, duration, profiles, vocal density and energy. Plans are recommendations and must be rehearsed before a real event.", keywords: ["preparation", "tracks", "bpm"])
        case .transitions: HelpTopic(id: topic.id, title: "Transitions", summary: "Understand plans, confidence and safeguards.", body: "Each transition includes a kind, duration, target BPM, confidence score and automation lanes. Deck volumes protect independently from the crossfader.", keywords: ["transition", "crossfader", "confidence"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .preflight: HelpTopic(id: topic.id, title: "Preflight", summary: "Block startup when evidence is insufficient.", body: "Preflight checks DJ software, mapping, devices, audio, emergency output and current state. Resolve blocking items before Live.", keywords: ["preflight", "check", "safety"])
        case .live: HelpTopic(id: topic.id, title: "Live mode", summary: "Monitor state and take control immediately.", body: "Keep the Mac powered, disable sleep and watch levels. A late or duplicate command must be ignored or reconciled, never applied blindly.", keywords: ["live", "sleep", "heat"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .iphone: HelpTopic(id: topic.id, title: "iPhone remote", summary: "Use iPhone as an optional interface.", body: "The iPhone complements the Mac but does not own audio continuity. If the connection drops, local Live continues.", keywords: ["iphone", "remote", "pairing"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .manualRecovery: HelpTopic(id: topic.id, title: "Manual recovery", summary: "Take control without creating a second action.", body: "Use immediate takeover, stabilize the audible deck, cancel pending automation, then observe the real DJ software state before restarting autopilot.", keywords: ["manual", "recovery", "takeover"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .emergencyPlayback: HelpTopic(id: topic.id, title: "Emergency playback", summary: "Keep audio audible during a failure.", body: "Prepare a tested local source independent from the network and primary DJ software. Return only after observing a stable state.", keywords: ["emergency", "silence", "fallback"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .troubleshooting: HelpTopic(id: topic.id, title: "Troubleshooting", summary: "Diagnose without hiding failures.", body: "Record time, state, backend, version and the last observed effect. Export an anonymized diagnostic. A retry is not success without effect confirmation.", keywords: ["troubleshooting", "diagnostic", "error"], relatedIncidentKinds: topic.relatedIncidentKinds)
        }
    }

    private static let spanishTopics: [HelpTopic] = frenchTopics.map { topic in
        switch topic.id {
        case .gettingStarted: HelpTopic(id: topic.id, title: "Primeros pasos", summary: "Configura MixPilot sin depender de Internet.", body: "Elige el software DJ, verifica los permisos de macOS, selecciona el dispositivo MIDI virtual y ejecuta el preflight. Mantén una fuente de audio de emergencia probada.", keywords: ["inicio", "configuración", "sin conexión"])
        case .djSoftware: HelpTopic(id: topic.id, title: "Software DJ", summary: "Selecciona y verifica Serato, rekordbox o djay.", body: "MixPilot nunca presupone que exista una API privada. La detección comprueba la aplicación, la versión y la ventana esperada. Tras una actualización, repite el preflight y valida el mapping.", keywords: ["serato", "rekordbox", "djay", "versión"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .connection: HelpTopic(id: topic.id, title: "Conexión local", summary: "Comprende MIDI, audio y el mando local.", body: "Live sigue funcionando sin Internet. MIDI y audio tienen prioridad. El iPhone es opcional y su pérdida no debe detener la reproducción.", keywords: ["conexión", "red", "midi", "audio"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .mappings: HelpTopic(id: topic.id, title: "Mappings", summary: "Valida los comandos antes de Live.", body: "Un mapping es fiable solo cuando cada comando produce el efecto esperado y observado. No publiques un mapping estable sin validación de hardware.", keywords: ["mapping", "comando", "validación"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .preparation: HelpTopic(id: topic.id, title: "Preparación del set", summary: "Analiza pistas y prepara transiciones.", body: "Comprueba BPM, duración, perfiles, densidad vocal y energía. Los planes son recomendaciones y deben ensayarse antes de un evento real.", keywords: ["preparación", "pistas", "bpm"])
        case .transitions: HelpTopic(id: topic.id, title: "Transiciones", summary: "Comprende planes, confianza y protecciones.", body: "Cada transición incluye tipo, duración, BPM objetivo, confianza y automatizaciones. Los volúmenes protegen independientemente del crossfader.", keywords: ["transición", "crossfader", "confianza"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .preflight: HelpTopic(id: topic.id, title: "Preflight", summary: "Bloquea el inicio si faltan pruebas.", body: "El preflight comprueba software DJ, mapping, dispositivos, audio, salida de emergencia y estado actual. Corrige los bloqueos antes de Live.", keywords: ["preflight", "comprobación", "seguridad"])
        case .live: HelpTopic(id: topic.id, title: "Modo Live", summary: "Vigila el estado y recupera el control.", body: "Mantén el Mac alimentado, desactiva el reposo y vigila niveles. Un comando tardío o duplicado debe ignorarse o reconciliarse.", keywords: ["live", "reposo", "temperatura"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .iphone: HelpTopic(id: topic.id, title: "Mando iPhone", summary: "Usa el iPhone como interfaz opcional.", body: "El iPhone complementa al Mac, pero no controla la continuidad de audio. Si se pierde la conexión, Live local continúa.", keywords: ["iphone", "mando", "emparejamiento"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .manualRecovery: HelpTopic(id: topic.id, title: "Recuperación manual", summary: "Recupera el control sin duplicar acciones.", body: "Usa la toma de control inmediata, estabiliza el deck audible, cancela automatizaciones pendientes y observa el estado real antes de reiniciar.", keywords: ["manual", "recuperación", "control"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .emergencyPlayback: HelpTopic(id: topic.id, title: "Reproducción de emergencia", summary: "Mantén audio durante un fallo.", body: "Prepara una fuente local probada e independiente de la red y del software DJ principal. Vuelve solo tras observar un estado estable.", keywords: ["emergencia", "silencio", "respaldo"], relatedIncidentKinds: topic.relatedIncidentKinds)
        case .troubleshooting: HelpTopic(id: topic.id, title: "Solución de problemas", summary: "Diagnostica sin ocultar errores.", body: "Anota hora, estado, backend, versión y último efecto observado. Exporta un diagnóstico anonimizado. Un retry no es éxito sin confirmación.", keywords: ["diagnóstico", "error", "problema"], relatedIncidentKinds: topic.relatedIncidentKinds)
        }
    }
}
