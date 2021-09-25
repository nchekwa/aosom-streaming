docker ps --filter "name=aosom-streaming" --format "table {{.ID}}\t{{.Names}}\t{{.State}}\t{{.RunningFor}}\t{{.Status}}"
