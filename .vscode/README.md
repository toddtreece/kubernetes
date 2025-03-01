## Dependencies

- Docker (for running etcd)
- OpenSSL (for cert gen)
- kubectl

## Debugging

1. Open this repo in VS Code
2. Hit F5 or select "Run > Start Debugging"
3. Place breakpoints in `staging/src/k8s.io/apiserver` or related code
4. Test with RBAC objects:
   ```
   kubectl --kubeconfig .vscode/dev-kubeconfig create -f .vscode/rbac.yaml
   ```

