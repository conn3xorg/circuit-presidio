# Local example

Applies circuit-presidio to a throwaway Rocky Linux 10 container with systemd. You need Conn3x and Podman.

Presidio runs under Podman inside that container, so the host container is privileged, which is simplest with rootful Podman. On a Mac, use the Podman machine's root connection. On Linux, use `sudo podman`:

```sh
export CONTAINER_CONNECTION=podman-machine-default-root   # macOS
export PODMAN="sudo podman"                               # Linux
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The first apply takes a minute or two, most of it pulling the analyzer's image, which carries spaCy's English model. The second plan says `No changes.`

`main.tf` gives the analyzer two recognizers of its own: a deny-list with the made-up code names `Bluebird` and `Quillfeather`, and a pattern for employee IDs such as `EMP-123456`. The analyzer listens on `127.0.0.1:5002` inside the container and the anonymizer on `127.0.0.1:5001`. The test images have no `curl`, so ask from inside the analyzer's container, which has Python:

```sh
ssh -p 2306 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 \
  podman exec -i presidio-analyzer python - <<'EOF'
import json, urllib.request as u
body = {"text": "Ship Quillfeather to EMP-123456 by Friday", "language": "en"}
req = u.Request("http://127.0.0.1:5002/analyze", json.dumps(body).encode(), {"Content-Type": "application/json"})
print(u.build_opener(u.ProxyHandler({})).open(req).read().decode())
EOF
```

The answer finds `PROJECT_CODENAME`, `EMPLOYEE_ID` and `DATE_TIME`.

`up.sh` listens on `127.0.0.1:2306`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes the container, its volumes, the key and the state.
