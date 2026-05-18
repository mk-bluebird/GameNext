// File: crates/game-next-index/src/lib.rs
// Destination: GameNext/crates/game-next-index/src/lib.rs

#![feature(rust_2024_preview)]

use rusqlite::{params, Connection, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResearchTopic {
    pub topic_id: String,
    pub title: String,
    pub domain: String,
    pub status: String,
    pub abstract_: String,
    pub hypothesis: String,
}

pub fn init_index_schema(conn: &Connection) -> Result<()> {
    conn.execute_batch(include_str!("../../sql/game-next-research-index.sql"))
}

pub fn insert_research_topic(conn: &Connection, topic: &ResearchTopic) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO research_topic (topic_id, title, domain, status, abstract, hypothesis) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![topic.topic_id, topic.title, topic.domain, topic.status, topic.abstract_, topic.hypothesis],
    )?;
    Ok(())
}

pub fn query_open_topics(conn: &Connection, domain: Option<&str>) -> Result<Vec<ResearchTopic>> {
    let mut stmt = if let Some(d) = domain {
        conn.prepare(
            "SELECT topic_id, title, domain, status, abstract, hypothesis FROM research_topic WHERE status = 'open' AND domain = ?1"
        )?
    } else {
        conn.prepare(
            "SELECT topic_id, title, domain, status, abstract, hypothesis FROM research_topic WHERE status = 'open'"
        )?
    };
    let rows = if let Some(d) = domain {
        stmt.query_map(params![d], |row| {
            Ok(ResearchTopic {
                topic_id: row.get(0)?,
                title: row.get(1)?,
                domain: row.get(2)?,
                status: row.get(3)?,
                abstract_: row.get(4)?,
                hypothesis: row.get(5)?,
            })
        })?
    } else {
        stmt.query_map([], |row| {
            Ok(ResearchTopic {
                topic_id: row.get(0)?,
                title: row.get(1)?,
                domain: row.get(2)?,
                status: row.get(3)?,
                abstract_: row.get(4)?,
                hypothesis: row.get(5)?,
            })
        })?
    };
    rows.collect::<Result<Vec<_>>>()
}
