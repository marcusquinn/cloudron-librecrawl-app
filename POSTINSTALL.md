Sign in as `admin`. The generated password is in `/app/data/admin-password`:
read it in the app's Terminal with `cat /app/data/admin-password`, or run
`cloudron exec --app $CLOUDRON-APP-FQDN -- cat /app/data/admin-password`.

After signing in, set a new password in the Terminal with
`librecrawl-user reset-password admin`, then delete `/app/data/admin-password`.

Registration and guest access are disabled. Create an account for each person
or site with `librecrawl-user add`. See
[account administration](https://github.com/marcusquinn/cloudron-librecrawl-app/blob/main/docs/README.md)
for the commands.

**Warning:** signed-in users can crawl private addresses, other apps and the
Docker network. Create accounts only for trusted people and sites.
