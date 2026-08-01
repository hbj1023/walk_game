migrate((app) => {
  const settings = app.settings()
  settings.meta.appURL = "https://walk-master.com"
  app.save(settings)

  const users = app.findCollectionByNameOrId("users")
  users.resetPasswordTemplate.subject = "Walk Master 비밀번호 재설정"
  users.resetPasswordTemplate.body = `
<p>안녕하세요.</p>
<p>아래 버튼을 눌러 Walk Master 비밀번호를 새로 설정해주세요.</p>
<p>
  <a class="btn" href="{APP_URL}/?resetToken={TOKEN}" target="_blank" rel="noopener">비밀번호 재설정</a>
</p>
<p><i>본인이 요청하지 않았다면 이 메일을 무시하셔도 됩니다.</i></p>
`
  app.save(users)
})
