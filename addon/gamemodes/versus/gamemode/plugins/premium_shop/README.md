# Premium Shop

## Production Installation

1. Install [the PayNow.gg addon](https://github.com/paynow-gg/gmod-addon/tree/master) to link the game server to your account.

    This allows PayNow to send commands to your game server.

2. Create your game server [in the PayNow.gg Game Servers section](https://dashboard.paynow.gg/gameservers) and run the provided command in the server.

3. Set the `versus_premium_shop_url` ConVar to the URL of your premium shop. The default may be sufficient.

4. Setup the following commands in [the PayNow.gg Global Commands section](https://dashboard.paynow.gg/global-commands):
    - On Purchased: `versus_premium_order purchased {product.slug} {order.id} {order.customer.steam.id}`
    - On Expire: `versus_premium_order expired {product.slug} {order.id} {order.customer.steam.id}` (unused)
    - On Renew: `versus_premium_order renewed {product.slug} {order.id} {order.customer.steam.id}` (unused)
    - On Refund: `versus_premium_order refunded {product.slug} {order.id} {order.customer.steam.id}`
    - On Cancel: `versus_premium_order canceled {product.slug} {order.id} {order.customer.steam.id}`

    Ensure to set `Execute when online` for all commands and set them to execute on all Versus Game Servers.

5. Create a zip-file of the `paynow-template` directory and upload it to the PayNow.gg dashboard when selecting [the Webstore Template](https://dashboard.paynow.gg/webstore/templates)
