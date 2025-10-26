# Alpine Linux Demo: Playing Big Buck Bunny

Once Alpine boots and you login as root:

## 1. Setup networking
```bash
setup-interfaces -a
rc-service networking start
```

## 2. Setup package repos
```bash
setup-apkrepos -f
# Choose option 1 for fastest mirror
```
