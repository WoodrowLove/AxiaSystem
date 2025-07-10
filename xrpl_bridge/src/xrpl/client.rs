use tokio::time::{sleep, Duration};
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message;
use url::Url;
use anyhow::anyhow;
use futures_util::{SinkExt, StreamExt};

use crate::xrpl::types::{XRPLError, XRPLCommand};


/// Bootstraps the XRPL WebSocket client and starts the main event loop.
/// Will automatically reconnect with exponential backoff if disconnected.
pub async fn connect_to_xrpl() -> Result<(), XRPLError> {
    let endpoint = "wss://s.altnet.rippletest.net:51233"; // Testnet endpoint
    let mut retry_count = 0;
    let max_retries = 5;

    loop {
        match Url::parse(endpoint) {
            Ok(url) => {
                match connect_async(url).await {
                    Ok((ws_stream, _)) => {
                        println!("✅ Connected to XRPL WebSocket.");
                        retry_count = 0; // reset on success
                        let (mut write, mut read) = ws_stream.split();

                        // Send initial ping or config message if needed
                        let ping = serde_json::to_string(&XRPLCommand::Ping)?;
                        write.send(Message::Text(ping)).await?;

                        // Event loop
                        while let Some(msg) = read.next().await {
                            match msg {
                                Ok(Message::Text(txt)) => {
                                    println!("📥 XRPL Msg: {}", txt);
                                    // Here you would call `handle_xrpl_event(&txt)` eventually
                                },
                                Ok(_) => continue,
                                Err(e) => {
                                    eprintln!("⚠️ WebSocket error: {}", e);
                                    break;
                                }
                            }
                        }

                        eprintln!("🔌 XRPL connection lost. Reconnecting...");
                    }
                    Err(e) => {
                        eprintln!("❌ Failed to connect: {}", e);
                    }
                }
            }
            Err(_) => return Err(XRPLError::InvalidEndpoint("Invalid endpoint URL".to_string())),
        }

        if retry_count >= max_retries {
            return Err(XRPLError::ConnectionFailed(
                "Max retries reached. Could not connect to XRPL WebSocket.".to_string()
            ));
        }

        let backoff = 2u64.pow(retry_count.min(5)); // Cap backoff at 32s
        eprintln!("🔁 Reconnecting in {}s...", backoff);
        sleep(Duration::from_secs(backoff)).await;
        retry_count += 1;
    }
}


/// Subscribes to a given XRP address (and optional destination tag) over WebSocket.
pub async fn subscribe_to_address(address: &str, tag: Option<u32>) -> Result<(), XRPLError> {
    let endpoint = "wss://s.altnet.rippletest.net:51233";
    let url = Url::parse(endpoint).map_err(|e| XRPLError::InvalidEndpoint(e.to_string()))?;

    let (ws_stream, _) = connect_async(url).await.map_err(|e| {
            XRPLError::ConnectionFailed(format!("WebSocket error: {}", e))
        })?;

    let (mut write, mut read) = ws_stream.split();

    // Build subscription payload
    let mut params = vec![serde_json::json!(address)];
    if let Some(destination_tag) = tag {
        params.push(serde_json::json!({ "destination_tag": destination_tag }));
    }

    let subscribe_msg = serde_json::json!({
        "id": "subscribe_cmd",
        "command": "subscribe",
        "accounts": params
    });

    let msg_str = subscribe_msg.to_string();
    write.send(Message::Text(msg_str)).await.map_err(|e| {
        XRPLError::WebSocketSendFailed(format!("Send failed: {}", e))
    })?;

    println!("📡 Subscribed to address: {} with tag: {:?}", address, tag);

    // Just consume one message for test
    if let Some(Ok(Message::Text(response))) = read.next().await {
        println!("📥 Subscription Response: {}", response);
    }

    Ok(())
}