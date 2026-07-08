use clap::Parser;
use postgres_native_tls::MakeTlsConnector;
use time::{Date, Month};
use turso::{params, Builder};

#[derive(Parser, Debug)]
struct Args {
    #[arg(long)]
    pg: String,
    #[arg(long)]
    db: String,
    /// Disable server certificate validation for one-off imports through tunnels.
    #[arg(long)]
    danger_accept_invalid_certs: bool,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let mut tls_builder = native_tls::TlsConnector::builder();
    if args.danger_accept_invalid_certs {
        tls_builder.danger_accept_invalid_certs(true);
    }
    let tls = tls_builder.build()?;
    let tls = MakeTlsConnector::new(tls);
    let (pg, connection) = tokio_postgres::connect(&args.pg, tls).await?;
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("postgres connection error: {e}");
        }
    });

    let db = Builder::new_local(&args.db).build().await?;
    let conn = db.connect()?;
    conn.execute_batch(include_str!("../../migrations/0001_init.sql"))
        .await?;

    for row in pg
        .query(
            "SELECT id::text,email,encrypted_password,created_at::text FROM auth.users",
            &[],
        )
        .await?
    {
        let id: String = row.get(0);
        let email: String = row.get(1);
        let password_hash: Option<String> = row.get(2);
        let created_at: Option<String> = row.get(3);
        conn.execute(
            "INSERT OR IGNORE INTO users(id,email,password_hash,email_verified,created_at) VALUES(?,?,?,?,?)",
            params![
                id.as_str(),
                email.as_str(),
                password_hash.as_deref(),
                1_i64,
                created_at.as_deref().unwrap_or("1970-01-01T00:00:00Z")
            ],
        )
        .await?;
    }

    for row in pg
        .query(
            "SELECT id::text,book_name,owner::text FROM public.books",
            &[],
        )
        .await?
    {
        let id: String = row.get(0);
        let name: Option<String> = row.get(1);
        let owner: String = row.get(2);
        conn.execute(
            "INSERT OR IGNORE INTO books(id,name,owner,created_at) VALUES(?,?,?,?)",
            params![
                id.as_str(),
                name.as_deref(),
                owner.as_str(),
                "1970-01-01T00:00:00Z"
            ],
        )
        .await?;
    }

    for row in pg
        .query(
            "SELECT id::text,\"user\"::text,book::text FROM public.user_connections",
            &[],
        )
        .await?
    {
        let id: String = row.get(0);
        let user: String = row.get(1);
        let book: String = row.get(2);
        conn.execute(
            "INSERT OR IGNORE INTO book_members(id,user,book,created_at) VALUES(?,?,?,?)",
            params![
                id.as_str(),
                user.as_str(),
                book.as_str(),
                "1970-01-01T00:00:00Z"
            ],
        )
        .await?;
    }

    for row in pg
        .query(
            "SELECT id::text,person,quote,date::text,book::text,\"user\"::text FROM public.quotes",
            &[],
        )
        .await?
    {
        let id: String = row.get(0);
        let person: String = row.get(1);
        let quote: String = row.get(2);
        let date: String = row.get(3);
        let book: String = row.get(4);
        let user: Option<String> = row.get(5);
        conn.execute(
            "INSERT OR IGNORE INTO quotes(id,book,person,quote,date,created_by,created_at) VALUES(?,?,?,?,?,?,?)",
            params![
                id.as_str(),
                book.as_str(),
                person.as_str(),
                quote.as_str(),
                normalize_date(&date).as_str(),
                user.as_deref(),
                "1970-01-01T00:00:00Z"
            ],
        )
        .await?;
    }

    Ok(())
}

fn normalize_date(input: &str) -> String {
    let mut parts = input.split('-');
    let year = parts
        .next()
        .and_then(|p| p.parse::<i32>().ok())
        .unwrap_or(1970);
    let month_num = parts
        .next()
        .and_then(|p| p.parse::<u8>().ok())
        .unwrap_or(1)
        .clamp(1, 12);
    let day = parts.next().and_then(|p| p.parse::<u8>().ok()).unwrap_or(1);
    let month = Month::try_from(month_num).unwrap_or(Month::January);
    let last = last_day_of_month(year, month);
    let fixed_day = day.clamp(1, last);
    Date::from_calendar_date(year, month, fixed_day)
        .map(|d| d.to_string())
        .unwrap_or_else(|_| "1970-01-01".to_string())
}

fn last_day_of_month(year: i32, month: Month) -> u8 {
    let next = match month {
        Month::January => (year, Month::February),
        Month::February => (year, Month::March),
        Month::March => (year, Month::April),
        Month::April => (year, Month::May),
        Month::May => (year, Month::June),
        Month::June => (year, Month::July),
        Month::July => (year, Month::August),
        Month::August => (year, Month::September),
        Month::September => (year, Month::October),
        Month::October => (year, Month::November),
        Month::November => (year, Month::December),
        Month::December => (year + 1, Month::January),
    };
    (Date::from_calendar_date(next.0, next.1, 1).unwrap() - time::Duration::days(1)).day()
}

#[cfg(test)]
mod tests {
    use super::normalize_date;

    #[test]
    fn clamps_invalid_end_of_month_dates() {
        assert_eq!(normalize_date("2021-04-31"), "2021-04-30");
        assert_eq!(normalize_date("2021-02-29"), "2021-02-28");
        assert_eq!(normalize_date("2020-02-31"), "2020-02-29");
    }
}
