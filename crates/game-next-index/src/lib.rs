// File: crates/game-next-index/src/lib.rs
// Destination: GameNext/crates/game-next-index/src/lib.rs

#![feature(rust_2024_preview)]

use rusqlite::{params, Connection, Result};
use serde::{Deserialize, Serialize};

const RESEARCH_SCHEMA_SQL: &str = include_str!("../../sql/game-next-research-index.sql");
const ENGINE_COMPAT_SCHEMA_SQL: &str = include_str!("../../sql/game-next-engine-compat.sql");

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResearchTopic {
    pub topic_id: String,
    pub title: String,
    pub domain: String,
    pub status: String,
    pub abstract_text: String,
    pub hypothesis: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractInfo {
    pub contract_id: String,
    pub schema_path: String,
    pub version_major: i32,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TermDefinition {
    pub term: String,
    pub definition: String,
    pub source: String,
    pub related_contracts: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineInfo {
    pub engine_id: String,
    pub name: String,
    pub version: String,
    pub notes: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineContractCompat {
    pub engine_id: String,
    pub contract_id: String,
    pub support_level: String,
    pub notes: String,
}

pub fn init_index_schema(conn: &Connection) -> Result<()> {
    conn.execute_batch(RESEARCH_SCHEMA_SQL)?;
    conn.execute_batch(ENGINE_COMPAT_SCHEMA_SQL)?;
    Ok(())
}

pub fn insert_research_topic(conn: &Connection, topic: &ResearchTopic) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO research_topic (topic_id, title, domain, status, abstract, hypothesis)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![
            &topic.topic_id,
            &topic.title,
            &topic.domain,
            &topic.status,
            &topic.abstract_text,
            &topic.hypothesis
        ],
    )?;
    Ok(())
}

pub fn query_open_topics(conn: &Connection, domain: Option<&str>) -> Result<Vec<ResearchTopic>> {
    let mut stmt = match domain {
        Some(_) => conn.prepare(
            "SELECT topic_id, title, domain, status, abstract, hypothesis
             FROM research_topic
             WHERE status IN ('open','in-progress') AND domain = ?1
             ORDER BY topic_id ASC",
        )?,
        None => conn.prepare(
            "SELECT topic_id, title, domain, status, abstract, hypothesis
             FROM research_topic
             WHERE status IN ('open','in-progress')
             ORDER BY topic_id ASC",
        )?,
    };

    let iter = match domain {
        Some(d) => stmt.query_map(params![d], |row| {
            Ok(ResearchTopic {
                topic_id: row.get(0)?,
                title: row.get(1)?,
                domain: row.get(2)?,
                status: row.get(3)?,
                abstract_text: row.get(4)?,
                hypothesis: row.get(5)?,
            })
        })?,
        None => stmt.query_map([], |row| {
            Ok(ResearchTopic {
                topic_id: row.get(0)?,
                title: row.get(1)?,
                domain: row.get(2)?,
                status: row.get(3)?,
                abstract_text: row.get(4)?,
                hypothesis: row.get(5)?,
            })
        })?,
    };

    iter.collect()
}

pub fn query_contract_by_id(conn: &Connection, contract_id: &str) -> Result<Option<ContractInfo>> {
    let mut stmt = conn.prepare(
        "SELECT contract_id, schema_path, version_major, description
         FROM contract_registry
         WHERE contract_id = ?1",
    )?;

    let mut rows = stmt.query(params![contract_id])?;
    if let Some(row) = rows.next()? {
        Ok(Some(ContractInfo {
            contract_id: row.get(0)?,
            schema_path: row.get(1)?,
            version_major: row.get(2)?,
            description: row.get(3)?,
        }))
    } else {
        Ok(None)
    }
}

pub fn define_term(conn: &Connection, term: &str, definition: &str, source: &str) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO term_definition (term, definition, source)
         VALUES (?1, ?2, ?3)",
        params![term, definition, source],
    )?;
    Ok(())
}

pub fn link_term_to_contract(conn: &Connection, term: &str, contract_id: &str) -> Result<()> {
    conn.execute(
        "INSERT OR IGNORE INTO term_contract_usage (term, contract_id)
         VALUES (?1, ?2)",
        params![term, contract_id],
    )?;
    Ok(())
}

pub fn lookup_term(conn: &Connection, term: &str) -> Result<Option<TermDefinition>> {
    let mut stmt = conn.prepare(
        "SELECT t.term, t.definition, t.source
         FROM term_definition t
         WHERE t.term = ?1 COLLATE NOCASE",
    )?;
    let mut rows = stmt.query(params![term])?;

    if let Some(row) = rows.next()? {
        let term_val: String = row.get(0)?;
        let definition: String = row.get(1)?;
        let source: String = row.get(2)?;

        let mut related_stmt =
            conn.prepare("SELECT contract_id FROM term_contract_usage WHERE term = ?1")?;
        let related_contracts: Vec<String> = related_stmt
            .query_map(params![&term_val], |r| r.get(0))?
            .collect::<Result<Vec<_>>>()?;

        Ok(Some(TermDefinition {
            term: term_val,
            definition,
            source,
            related_contracts,
        }))
    } else {
        Ok(None)
    }
}

pub fn register_engine(
    conn: &Connection,
    engine: &EngineInfo,
) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO engine_registry (engine_id, name, version, notes)
         VALUES (?1, ?2, ?3, ?4)",
        params![&engine.engine_id, &engine.name, &engine.version, &engine.notes],
    )?;
    Ok(())
}

pub fn register_engine_compat(
    conn: &Connection,
    compat: &EngineContractCompat,
) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO engine_contract_compat
         (engine_id, contract_id, support_level, notes)
         VALUES (?1, ?2, ?3, ?4)",
        params![
            &compat.engine_id,
            &compat.contract_id,
            &compat.support_level,
            &compat.notes
        ],
    )?;
    Ok(())
}

pub fn find_gaps_for_engine(conn: &Connection, engine_id: &str) -> Result<Vec<String>> {
    let mut stmt = conn.prepare(
        "SELECT c.contract_id
         FROM contract_registry c
         LEFT JOIN engine_contract_compat ecc
           ON c.contract_id = ecc.contract_id
           AND ecc.engine_id = ?1
         WHERE ecc.contract_id IS NULL
            OR ecc.support_level = 'unsupported'",
    )?;

    let rows = stmt.query_map(params![engine_id], |row| row.get(0))?;
    rows.collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_init_and_basic_queries() {
        let conn = Connection::open_in_memory().unwrap();
        init_index_schema(&conn).unwrap();

        let topic = ResearchTopic {
            topic_id: "test-topic".to_string(),
            title: "Test Topic".to_string(),
            domain: "tools".to_string(),
            status: "open".to_string(),
            abstract_text: "Test abstract".to_string(),
            hypothesis: "Test hypothesis".to_string(),
        };
        insert_research_topic(&conn, &topic).unwrap();

        let topics = query_open_topics(&conn, Some("tools")).unwrap();
        assert_eq!(topics.len(), 1);
        assert_eq!(topics[0].topic_id, "test-topic");

        define_term(&conn, "CIC", "Constellation Integrity Coefficient", "game-next-docs").unwrap();
        link_term_to_contract(&conn, "CIC", "game-next-bci-geometry-binding-v1").unwrap();

        let term = lookup_term(&conn, "CIC").unwrap().unwrap();
        assert_eq!(term.term, "CIC");
        assert!(term.definition.contains("Constellation Integrity"));
        assert!(term.related_contracts.contains(&"game-next-bci-geometry-binding-v1".to_string()));

        let engine = EngineInfo {
            engine_id: "unreal-5".to_string(),
            name: "Unreal Engine".to_string(),
            version: "5".to_string(),
            notes: "Baseline target".to_string(),
        };
        register_engine(&conn, &engine).unwrap();

        conn.execute(
            "INSERT INTO contract_registry (contract_id, schema_path, version_major, description)
             VALUES ('game-next-bci-geometry-binding-v1', 'schemas/game-next-bci-geometry-binding-v1.json', 1, 'BCI geometry binding')",
            [],
        )
        .unwrap();

        let compat = EngineContractCompat {
            engine_id: "unreal-5".to_string(),
            contract_id: "game-next-bci-geometry-binding-v1".to_string(),
            support_level: "native".to_string(),
            notes: "Direct material mapping supported".to_string(),
        };
        register_engine_compat(&conn, &compat).unwrap();

        let gaps = find_gaps_for_engine(&conn, "unreal-5").unwrap();
        assert!(!gaps
            .iter()
            .any(|id| id == "game-next-bci-geometry-binding-v1"));
    }
}
