// cpp/token_ai/token_ai_index_engine.cpp
// Token-AI Index Engine
//
// Scrubbed and transformed from a GameNext/Rust index crate into a C++17
// Token-AI engine that:
//   - Initializes research + contract + term + engine-compat schemas.
//   - Inserts and queries research topics for Token-AI domains.
//   - Manages contract registry lookups.
//   - Defines and links terms to contracts.
//   - Registers engine stacks and computes support gaps.
//
// This file uses SQLite via the C API and is suitable for GitHub-hosted
// Token-AI services and tools.

#include <sqlite3.h>

#include <string>
#include <vector>
#include <stdexcept>
#include <utility>

namespace token_ai {

// ---------------------------------------------------------------------
// Schema bootstrap (Token-AI–centric)
// ---------------------------------------------------------------------

static const char* TOKEN_AI_INDEX_SCHEMA_SQL = R"SQL(
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Research topics
CREATE TABLE IF NOT EXISTS research_topic (
    topic_id      TEXT PRIMARY KEY,
    title         TEXT NOT NULL,
    domain        TEXT NOT NULL,
    status        TEXT NOT NULL,
    abstract      TEXT,
    hypothesis    TEXT,
    created_date  TEXT NOT NULL DEFAULT (date('now')),
    last_updated  TEXT NOT NULL DEFAULT (date('now')),
    CHECK (domain IN (
        'token-budgeting',
        'compression',
        'telemetry',
        'eco-impact',
        'prompt-guard',
        'ai-systems',
        'tools',
        'networking'
    )),
    CHECK (status IN ('open','in-progress','implemented','speculative','deferred'))
);

CREATE INDEX IF NOT EXISTS idx_research_domain_status
    ON research_topic(domain, status);

CREATE INDEX IF NOT EXISTS idx_research_status_open
    ON research_topic(status)
    WHERE status IN ('open','in-progress');

-- Contract registry
CREATE TABLE IF NOT EXISTS contract_registry (
    contract_id   TEXT PRIMARY KEY,
    schema_path   TEXT NOT NULL UNIQUE,
    version_major INTEGER NOT NULL,
    description   TEXT NOT NULL,
    created_date  TEXT NOT NULL DEFAULT (date('now')),
    deprecated    INTEGER NOT NULL DEFAULT 0,
    CHECK (version_major >= 1)
);

CREATE INDEX IF NOT EXISTS idx_contract_version
    ON contract_registry(version_major);

-- Term definitions
CREATE TABLE IF NOT EXISTS term_definition (
    term         TEXT PRIMARY KEY COLLATE NOCASE,
    definition   TEXT NOT NULL,
    source       TEXT NOT NULL,
    CHECK (source IN ('authoritative','contributed','ai-inferred'))
);

CREATE TABLE IF NOT EXISTS term_contract_usage (
    term        TEXT NOT NULL COLLATE NOCASE,
    contract_id TEXT NOT NULL,
    PRIMARY KEY (term, contract_id),
    FOREIGN KEY (term) REFERENCES term_definition(term) ON DELETE CASCADE,
    FOREIGN KEY (contract_id) REFERENCES contract_registry(contract_id) ON DELETE CASCADE
);

-- Engine registry and compatibility
CREATE TABLE IF NOT EXISTS engine_registry (
    engine_id TEXT PRIMARY KEY,
    name      TEXT NOT NULL,
    version   TEXT NOT NULL,
    notes     TEXT
);

CREATE TABLE IF NOT EXISTS engine_contract_compat (
    engine_id     TEXT NOT NULL,
    contract_id   TEXT NOT NULL,
    support_level TEXT NOT NULL,
    notes         TEXT,
    PRIMARY KEY (engine_id, contract_id),
    FOREIGN KEY (engine_id) REFERENCES engine_registry(engine_id) ON DELETE CASCADE,
    FOREIGN KEY (contract_id) REFERENCES contract_registry(contract_id) ON DELETE CASCADE,
    CHECK (support_level IN ('native','adapter','plugin','planned','unsupported'))
);

CREATE INDEX IF NOT EXISTS idx_engine_support
    ON engine_contract_compat(engine_id, support_level);
)SQL";

// ---------------------------------------------------------------------
// Simple RAII wrapper for sqlite3 statements
// ---------------------------------------------------------------------

class SqliteStmt {
public:
    SqliteStmt(sqlite3* db, const std::string& sql) : stmt_(nullptr) {
        if (sqlite3_prepare_v2(db, sql.c_str(), -1, &stmt_, nullptr) != SQLITE_OK) {
            throw std::runtime_error("Failed to prepare statement: " + sql);
        }
    }

    ~SqliteStmt() {
        if (stmt_) {
            sqlite3_finalize(stmt_);
        }
    }

    sqlite3_stmt* get() { return stmt_; }

private:
    sqlite3_stmt* stmt_;
};

// ---------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------

struct ResearchTopic {
    std::string topicId;
    std::string title;
    std::string domain;
    std::string status;
    std::string abstractText;
    std::string hypothesis;
};

struct ContractInfo {
    std::string contractId;
    std::string schemaPath;
    int versionMajor;
    std::string description;
};

struct TermDefinition {
    std::string term;
    std::string definition;
    std::string source;
    std::vector<std::string> relatedContracts;
};

struct EngineInfo {
    std::string engineId;
    std::string name;
    std::string version;
    std::string notes;
};

struct EngineContractCompat {
    std::string engineId;
    std::string contractId;
    std::string supportLevel;
    std::string notes;
};

// ---------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------

inline void initIndexSchema(sqlite3* db) {
    char* errmsg = nullptr;
    if (sqlite3_exec(db, TOKEN_AI_INDEX_SCHEMA_SQL, nullptr, nullptr, &errmsg) != SQLITE_OK) {
        std::string msg = errmsg ? errmsg : "Unknown error";
        sqlite3_free(errmsg);
        throw std::runtime_error("Failed to initialize Token-AI index schema: " + msg);
    }
}

// ---------------------------------------------------------------------
// Research topic operations
// ---------------------------------------------------------------------

inline void insertResearchTopic(sqlite3* db, const ResearchTopic& topic) {
    const char* sql =
        "INSERT OR REPLACE INTO research_topic "
        "(topic_id, title, domain, status, abstract, hypothesis) "
        "VALUES (?, ?, ?, ?, ?, ?)";

    SqliteStmt stmt(db, sql);
    sqlite3_bind_text(stmt.get(), 1, topic.topicId.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 2, topic.title.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 3, topic.domain.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 4, topic.status.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 5, topic.abstractText.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 6, topic.hypothesis.c_str(), -1, SQLITE_TRANSIENT);

    if (sqlite3_step(stmt.get()) != SQLITE_DONE) {
        throw std::runtime_error("Failed to insert research_topic");
    }
}

inline std::vector<ResearchTopic> queryOpenTopics(sqlite3* db,
                                                  const std::string* domainOpt) {
    const char* sqlWithDomain =
        "SELECT topic_id, title, domain, status, abstract, hypothesis "
        "FROM research_topic "
        "WHERE status IN ('open','in-progress') AND domain = ?1 "
        "ORDER BY topic_id ASC";

    const char* sqlWithoutDomain =
        "SELECT topic_id, title, domain, status, abstract, hypothesis "
        "FROM research_topic "
        "WHERE status IN ('open','in-progress') "
        "ORDER BY topic_id ASC";

    SqliteStmt stmt(db, domainOpt ? sqlWithDomain : sqlWithoutDomain);

    if (domainOpt) {
        sqlite3_bind_text(stmt.get(), 1, domainOpt->c_str(), -1, SQLITE_TRANSIENT);
    }

    std::vector<ResearchTopic> topics;
    while (true) {
        int rc = sqlite3_step(stmt.get());
        if (rc == SQLITE_ROW) {
            ResearchTopic t;
            t.topicId      = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 0));
            t.title        = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 1));
            t.domain       = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 2));
            t.status       = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 3));
            t.abstractText = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 4));
            t.hypothesis   = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 5));
            topics.push_back(std::move(t));
        } else if (rc == SQLITE_DONE) {
            break;
        } else {
            throw std::runtime_error("Failed to query open research topics");
        }
    }
    return topics;
}

// ---------------------------------------------------------------------
// Contract operations
// ---------------------------------------------------------------------

inline void insertContract(sqlite3* db, const ContractInfo& contract) {
    const char* sql =
        "INSERT OR REPLACE INTO contract_registry "
        "(contract_id, schema_path, version_major, description) "
        "VALUES (?, ?, ?, ?)";

    SqliteStmt stmt(db, sql);
    sqlite3_bind_text(stmt.get(), 1, contract.contractId.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 2, contract.schemaPath.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt.get(), 3, contract.versionMajor);
    sqlite3_bind_text(stmt.get(), 4, contract.description.c_str(), -1, SQLITE_TRANSIENT);

    if (sqlite3_step(stmt.get()) != SQLITE_DONE) {
        throw std::runtime_error("Failed to insert contract_registry entry");
    }
}

inline bool queryContractById(sqlite3* db,
                              const std::string& contractId,
                              ContractInfo& out) {
    const char* sql =
        "SELECT contract_id, schema_path, version_major, description "
        "FROM contract_registry "
        "WHERE contract_id = ?1";

    SqliteStmt stmt(db, sql);
    sqlite3_bind_text(stmt.get(), 1, contractId.c_str(), -1, SQLITE_TRANSIENT);

    int rc = sqlite3_step(stmt.get());
    if (rc == SQLITE_ROW) {
        out.contractId  = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 0));
        out.schemaPath  = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 1));
        out.versionMajor = sqlite3_column_int(stmt.get(), 2);
        out.description = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 3));
        return true;
    }
    if (rc == SQLITE_DONE) {
        return false;
    }
    throw std::runtime_error("Failed to query contract by id");
}

// ---------------------------------------------------------------------
// Term definition operations
// ---------------------------------------------------------------------

inline void defineTerm(sqlite3* db,
                       const std::string& term,
                       const std::string& definition,
                       const std::string& source) {
    const char* sql =
        "INSERT OR REPLACE INTO term_definition (term, definition, source) "
        "VALUES (?, ?, ?)";

    SqliteStmt stmt(db, sql);
    sqlite3_bind_text(stmt.get(), 1, term.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 2, definition.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 3, source.c_str(), -1, SQLITE_TRANSIENT);

    if (sqlite3_step(stmt.get()) != SQLITE_DONE) {
        throw std::runtime_error("Failed to define term");
    }
}

inline void linkTermToContract(sqlite3* db,
                               const std::string& term,
                               const std::string& contractId) {
    const char* sql =
        "INSERT OR IGNORE INTO term_contract_usage (term, contract_id) "
        "VALUES (?, ?)";

    SqliteStmt stmt(db, sql);
    sqlite3_bind_text(stmt.get(), 1, term.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 2, contractId.c_str(), -1, SQLITE_TRANSIENT);

    if (sqlite3_step(stmt.get()) != SQLITE_DONE) {
        throw std::runtime_error("Failed to link term to contract");
    }
}

inline bool lookupTerm(sqlite3* db,
                       const std::string& term,
                       TermDefinition& out) {
    const char* sqlTerm =
        "SELECT t.term, t.definition, t.source "
        "FROM term_definition t "
        "WHERE t.term = ?1 COLLATE NOCASE";

    SqliteStmt stmtTerm(db, sqlTerm);
    sqlite3_bind_text(stmtTerm.get(), 1, term.c_str(), -1, SQLITE_TRANSIENT);

    int rc = sqlite3_step(stmtTerm.get());
    if (rc == SQLITE_ROW) {
        out.term       = reinterpret_cast<const char*>(sqlite3_column_text(stmtTerm.get(), 0));
        out.definition = reinterpret_cast<const char*>(sqlite3_column_text(stmtTerm.get(), 1));
        out.source     = reinterpret_cast<const char*>(sqlite3_column_text(stmtTerm.get(), 2));
    } else if (rc == SQLITE_DONE) {
        return false;
    } else {
        throw std::runtime_error("Failed to query term_definition");
    }

    // Fetch related contracts
    const char* sqlRelated =
        "SELECT contract_id FROM term_contract_usage WHERE term = ?1";

    SqliteStmt stmtRelated(db, sqlRelated);
    sqlite3_bind_text(stmtRelated.get(), 1, out.term.c_str(), -1, SQLITE_TRANSIENT);

    out.relatedContracts.clear();
    while (true) {
        int rr = sqlite3_step(stmtRelated.get());
        if (rr == SQLITE_ROW) {
            const char* cid = reinterpret_cast<const char*>(sqlite3_column_text(stmtRelated.get(), 0));
            out.relatedContracts.emplace_back(cid);
        } else if (rr == SQLITE_DONE) {
            break;
        } else {
            throw std::runtime_error("Failed to query term_contract_usage");
        }
    }

    return true;
}

// ---------------------------------------------------------------------
// Engine registry + compatibility operations
// ---------------------------------------------------------------------

inline void registerEngine(sqlite3* db, const EngineInfo& engine) {
    const char* sql =
        "INSERT OR REPLACE INTO engine_registry "
        "(engine_id, name, version, notes) "
        "VALUES (?, ?, ?, ?)";

    SqliteStmt stmt(db, sql);
    sqlite3_bind_text(stmt.get(), 1, engine.engineId.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 2, engine.name.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 3, engine.version.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 4, engine.notes.c_str(), -1, SQLITE_TRANSIENT);

    if (sqlite3_step(stmt.get()) != SQLITE_DONE) {
        throw std::runtime_error("Failed to register engine");
    }
}

inline void registerEngineCompat(sqlite3* db,
                                 const EngineContractCompat& compat) {
    const char* sql =
        "INSERT OR REPLACE INTO engine_contract_compat "
        "(engine_id, contract_id, support_level, notes) "
        "VALUES (?, ?, ?, ?)";

    SqliteStmt stmt(db, sql);
    sqlite3_bind_text(stmt.get(), 1, compat.engineId.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 2, compat.contractId.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 3, compat.supportLevel.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt.get(), 4, compat.notes.c_str(), -1, SQLITE_TRANSIENT);

    if (sqlite3_step(stmt.get()) != SQLITE_DONE) {
        throw std::runtime_error("Failed to register engine_contract_compat");
    }
}

// Find gaps: contracts not supported or explicitly unsupported for an engine.
inline std::vector<std::string> findGapsForEngine(sqlite3* db,
                                                  const std::string& engineId) {
    const char* sql =
        "SELECT c.contract_id "
        "FROM contract_registry c "
        "LEFT JOIN engine_contract_compat ecc "
        "  ON c.contract_id = ecc.contract_id "
        "  AND ecc.engine_id = ?1 "
        "WHERE ecc.contract_id IS NULL "
        "   OR ecc.support_level = 'unsupported'";

    SqliteStmt stmt(db, sql);
    sqlite3_bind_text(stmt.get(), 1, engineId.c_str(), -1, SQLITE_TRANSIENT);

    std::vector<std::string> gaps;
    while (true) {
        int rc = sqlite3_step(stmt.get());
        if (rc == SQLITE_ROW) {
            const char* cid = reinterpret_cast<const char*>(sqlite3_column_text(stmt.get(), 0));
            gaps.emplace_back(cid);
        } else if (rc == SQLITE_DONE) {
            break;
        } else {
            throw std::runtime_error("Failed to query gaps for engine");
        }
    }
    return gaps;
}

} // namespace token_ai
