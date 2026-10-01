## Credentials Management

### Edit Credentials
* **Development**:
  ```bash
  EDITOR="nano" bin/rails credentials:edit --environment development
  ```
  *(VS Code: `EDITOR="code --wait" bin/rails credentials:edit --environment development`)*

* **Test**:
  ```bash
  EDITOR="nano" bin/rails credentials:edit --environment test
  ```

* **Production**:
  ```bash
  EDITOR="nano" bin/rails credentials:edit --environment production
  ```

### Inspect Decrypted Credentials (View Only)
```bash
bin/rails credentials:show --environment development
bin/rails credentials:show --environment test
bin/rails credentials:show --environment production
```
