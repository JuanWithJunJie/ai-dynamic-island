# GitHub SSH 推送指引

适用仓库：
`JuanWithJunJie/ai-dynamic-island`

适用工作目录：
`/Users/lijunjie/Documents/AIproject/macirland`

## 目标
- 把仓库的 GitHub 推送协议切到 SSH
- 验证本机 SSH 能登录 GitHub
- 用 SSH 成功执行 `git push`

## 操作步骤

### 1. 检查本机是否已有 SSH key
```bash
ls -la ~/.ssh
test -f ~/.ssh/id_ed25519.pub && cat ~/.ssh/id_ed25519.pub
```

### 2. 如果没有 `~/.ssh/id_ed25519.pub`，生成一把新的
```bash
ssh-keygen -t ed25519 -C "1475370932@qq.com" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

### 3. 优先用 `gh` 把公钥添加到 GitHub
```bash
gh auth refresh -h github.com -s admin:public_key
gh ssh-key add ~/.ssh/id_ed25519.pub --title "macirland-codex-$(hostname -s)-$(date +%Y%m%d-%H%M%S)"
```

### 4. 如果 `gh` 因 scope 不足失败，改用浏览器登录态添加公钥
打开：
`https://github.com/settings/keys`

然后：
- 进入 `New SSH key`
- `Title` 填：`macirland-codex-主机名-时间戳`
- `Key` 填 `~/.ssh/id_ed25519.pub` 的内容
- 提交
- 如果出现 `Confirm access`，由用户手动完成一次确认

### 5. 把 GitHub 主机加入 `known_hosts`
```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true
```

### 6. 验证 SSH 登录
```bash
ssh -o StrictHostKeyChecking=accept-new -T git@github.com
```

成功标志通常类似：
```text
Hi JuanWithJunJie! You've successfully authenticated, but GitHub does not provide shell access.
```

注意：
这一步即使退出码不是 `0`，只要出现 `successfully authenticated` 就算成功。

### 7. 把当前仓库 `origin` 改成 SSH
```bash
git remote set-url origin git@github.com:JuanWithJunJie/ai-dynamic-island.git
git remote -v
```

### 8. 推送当前分支
```bash
git branch --show-current
git push -u origin "$(git branch --show-current)"
```

### 9. 确认远端分支已存在
```bash
git ls-remote --heads origin "$(git branch --show-current)"
```

## 成功标准
- `ssh -T git@github.com` 显示 `successfully authenticated`
- `git remote -v` 显示 `git@github.com:JuanWithJunJie/ai-dynamic-island.git`
- `git push -u origin ...` 成功
- `git ls-remote --heads origin ...` 能看到对应分支

## 注意事项
- 不要再把 `origin` 改回 HTTPS
- 这个仓库后续统一走 SSH 推送
- 如果卡在 GitHub 的 `Confirm access`，先让用户手动确认，再继续执行后续步骤
